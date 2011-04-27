#--
# Copyleft meh. [http://meh.doesntexist.org | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free software: you can redistribute it and/or modify
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

module Packo
  def self.debug (argument, options={})
    if !Packo.const_defined?(:System) || (!System.env[:DEBUG] && !options[:force])
      return
    end

    if System.env[:DEBUG].to_i < (options[:level] || 1) && !options[:force]
      return
    end

    output = "[#{Time.new}] From: #{caller[0, options[:deep] || 1].join("\n")}\n"

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
      before: 'module ::Packo::RBuild;',
      after:  ';end'
    }

    files = {}

    if package
      if File.exists?("#{path}/digest.xml") && (digest = Nokogiri::XML.parse(File.read("#{path}/digest.xml")))
        features = digest.xpath("//build[@version = '#{package.version}'][@slot = '#{package.slot}']/features").first

        if features
          features.text.split(' ').each {|feature|
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

        # FIXME: maybe check slot too?
        digest.xpath("//build[@version = '#{package.version}']/files/file").each {|file|
          tmp = OpenStruct.new(
            name:   file['name'],
            url:    file['url'],
            digest: file.text
          )

          files[file['name']] = tmp
          files[file['url']]  = tmp
        }
      end

      begin
        Packo.load "#{path}/#{package.name}.rbuild", options

        if (pkg = RBuild::Package.last) && (tmp = File.read("#{path}/#{package.name}.rbuild").split(/^__END__$/)).length > 1
          pkg.filesystem.parse(tmp.last.lstrip)
        end
      rescue Exception => e
        Packo.debug e
      end

      Packo.load "#{path}/#{package.name}-#{package.version}.rbuild", options

      if RBuild::Package.last.name == package.name && RBuild::Package.last.version == package.version
        RBuild::Package.last.filesystem.merge!(pkg.filesystem)

        if (tmp = File.read("#{path}/#{package.name}-#{package.version}.rbuild").split(/^__END__$/)).length > 1
          RBuild::Package.last.filesystem.parse(tmp.last.lstrip)
        end

        if File.directory?("#{path}/data")
          RBuild::Package.last.filesystem.load("#{path}/data")
        end

        RBuild::Package.last.digests = files

        return RBuild::Package.last
      end
    else
      begin
        Packo.load path, options

        if (pkg = RBuild::Package.last) && (tmp = File.read(path).split(/^__END__$/)).length > 1
          pkg.filesystem.parse(tmp.last.lstrip)
        end
      rescue Exception => e
        Packo.debug e
      end

      return RBuild::Package.last
    end
  end
end

require 'packo/version'
require 'packo/extensions'
require 'packo/system'
require 'packo/do'
require 'packo/cli'
require 'packo/repository'
require 'packo/package'
