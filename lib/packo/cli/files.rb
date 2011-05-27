# :encoding => utf-8
#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free :software => you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# packo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with packo. If not, see <http://www.gnu.org/licenses/>.
#++

require 'packo/cli'

module Packo; module CLI

class Files < Thor
  include Thor::Actions

  class_option :help, :type => :boolean, :desc => 'Show help usage'

  desc 'package PACKAGE', 'Get a file list of a given package'
  def package (name)
    if name.end_with?('.pko')
      require 'packo/rbuild'

      path = "#{System.env[:TMP]}/.__packo_unpacked/#{File.basename(name)}"
      RBuild::Modules::Packager.unpack(File.realpath(name), path)

      length = "#{path}/dist".length

      Find.find("#{path}/dist") {|file|
        type = nil
        path = "/#{file[length, file.length]}".gsub(%r{/*/}, '/').sub(%r{/$}, '')
        meta = nil

        if File.directory? file
          type = :dir
        elsif File.symlink? file
          type = :sym
          meta = File.readlink file
        elsif File.file? file
          type = :obj
        end

        case type
          when :dir; puts "--- #{path if path != '/'}/"
          when :sym; puts ">>> #{path} -> #{meta}".cyan.bold
          when :obj; puts ">>> #{path}".bold
        end
      }
    else
      require 'packo/models'

      package = Models.search_installed(name).first
      root    = Path.new(package.destination || '/')

      if !package
        fatal "No package matches #{name}"
        exit! 10
      end

      package.model.contents.each {|content| content.check!
        case content.type
          when :dir; puts "--- #{Path.clean(root + content.path)}"
          when :sym; puts ">>> #{Path.clean(root + content.path)} -> #{content.meta}".cyan.bold
          when :obj; puts ">>> #{Path.clean(root + content.path)}".bold
        end
      }
    end
  end

  desc 'belongs FILE', 'Find out to what package a path belongs'
  def belongs (file)
    require 'packo/models'

    path    = Path.new(file).realpath.to_s
    path[0] = ''

    if content = Models::InstalledPackage::Content.first(:path => path)
      puts Package.wrap(content.installed_package).to_s
    else
      exit 1
    end
  end

  desc 'check [PACKAGE...]', 'Check contents for the given packages'
  def check (*names)
    require 'packo/models'

    packages = []

    if names.empty?
      packages << Models::InstalledPackage.all.map {|pkg|
        Package.wrap(pkg)
      }
    else
      names.each {|name|
        packages << Models.search_installed(name)
      }
    end

    packages.flatten.compact.each {|package|
      print "[#{package.repository.black.bold}] " if package.repository
      print "#{package.tags}/" unless package.tags.empty?
      print package.name.bold
      print "-#{package.version.to_s.red}"
      print " (#{package.slot.to_s.blue.bold})" if package.slot
      print " [#{package.features}]" unless package.features.empty?
      print " {#{package.flavor}}"   unless package.flavor.empty?
      print "\n"

      package.model.contents.each {|content|
        path = Path.clean((package.model.destination || '/') + content.path[1, content.path.length])

        case content.type
          when :dir
            if !(File.directory?(path) rescue false)
              puts "#{'FAIL ' if System.env[:NO_COLORS]}--- #{path}#{'/' if path != '/'}".red
            else
              puts "#{'OK   ' if System.env[:NO_COLORS]}--- #{path}#{'/' if path != '/'}".green
            end

          when :sym
            if content.meta != (File.readlink(path) rescue nil)
              puts "#{'FAIL ' if System.env[:NO_COLORS]}>>> #{path} -> #{content.meta}".red
            else
              puts "#{'OK   ' if System.env[:NO_COLORS]}>>> #{path} -> #{content.meta}".green
            end

          when :obj
            if content.meta != (Packo.digest(path) rescue nil)
              puts "#{'FAIL ' if System.env[:NO_COLORS]}>>> #{path}".red
            else
              puts "#{'OK   ' if System.env[:NO_COLORS]}>>> #{path}".green
            end
        end
      }

      puts ''
    }
  end
end

end; end
