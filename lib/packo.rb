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

require 'packo/utils'
require 'packo/extensions'

module Packo
  def self.debug (argument, options={})
    if !Packo.const_defined?(:System) || (!System.env[:DEBUG] && !options[:force])
      return
    end

    if System.env[:DEBUG].to_i < (options[:level] || 1) && !options[:force]
      return
    end

    output = "[#{Time.new}] :From => #{caller[0, options[:deep] || 1].join("\n")}\n"

    if argument.is_a?(Exception)
      output << "#{argument.class}: #{argument.message}\n"
      output << argument.backtrace.collect {|stack|
        stack
      }.join("\n")
      output << "\n\n"
    elsif argument.is_a?(String)
      output << "#{argument}\n"
    else
      output << "#{argument.inspect}\n"
    end

    if options[:separator]
      output << options[:separator]
    end

    $stderr.puts output
  end

  def self.loadPackage (path, package=nil)
    options = {
      :before => %{
        module ::Packo::RBuild
        include ::Packo::RBuild::Modules
        include ::Packo::RBuild::Behaviors
      },

      :after => %{
        end
      }
    }

    files = {}

    if package
      if File.exists?("#{path}/digest.yml") && (digest = YAML.parse_file("#{path}/digest.yml").transform)
        pkg = digest['packages'].find {|pkg|
          pkg['version'] == package.version && (!package.slot || pkg['slot'] == package.slot)
        }

        if pkg
          if pkg['features']
            pkg['features'].split(' ').each {|feature|
              next if RBuild::Features::Default[feature.to_sym]

              (package.environment || Environment.new).profiles.each {|profile|
                begin
                  Packo.load "#{profile.features}/#{feature}", options
                rescue LoadError
                rescue Exception => e
                  CLI.warn "Something went wrong while loading #{feature} feature." if System.env[:VERBOSE]
                  Packo.debug e
                end
              }
            }
          end

          pkg['files'].each {|file|
            tmp = OpenStruct.new(file)

            files[file['name']] = tmp
            files[file['url']]  = tmp
          }
        end
      end

      begin
        Packo.load "#{path}/#{package.name}.rbuild", options

        if (pkg = RBuild::Package.current) && (tmp = File.read("#{path}/#{package.name}.rbuild", :encoding => 'utf-8').split(/^__END__$/)).length > 1
          pkg.filesystem.parse(tmp.last.lstrip)
        end
      rescue Exception => e
        Packo.debug e
      end

      Packo.load "#{path}/#{package.name}-#{package.version}.rbuild", options

      if RBuild::Package.current.name == package.name && RBuild::Package.current.version == package.version
        RBuild::Package.current.filesystem.include(pkg.filesystem)

        if (tmp = File.read("#{path}/#{package.name}-#{package.version}.rbuild", :encoding => 'utf-8').split(/^__END__$/)).length > 1
          RBuild::Package.current.filesystem.parse(tmp.last.lstrip)
        end

        if File.directory?("#{path}/data")
          RBuild::Package.current.filesystem.load("#{path}/data")
        end

        RBuild::Package.current.digests = files

        return RBuild::Package.current
      end
    else
      begin
        Packo.load path, options

        if (pkg = RBuild::Package.current) && (tmp = File.read(path, :encoding => 'utf-8').split(/^__END__$/)).length > 1
          pkg.filesystem.parse(tmp.last.lstrip)
        end
      rescue Exception => e
        Packo.debug e
      end

      return RBuild::Package.current
    end
  end
end

require 'packo/version'
require 'packo/system'
require 'packo/do'
require 'packo/location'
require 'packo/repository'
require 'packo/package'
require 'packo/requirements'
