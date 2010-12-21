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

require 'packo/version'
require 'packo/extensions'
require 'packo/system'
require 'packo/cli'
require 'packo/package'
require 'packo/repository'

module Packo
  def self.sh (*cmd, &block)
    options = (Hash === cmd.last) ? cmd.pop : {}

    if !block_given?
      show_command = cmd.join(' ')
      show_command = show_command[0, 42] + '...' unless $trace

      block = lambda {|ok, status|
        ok or fail "Command failed with status (#{status.exitstatus}): [#{show_command}] in {#{Dir.pwd}}"
      }
    end

    if options[:silent]
      options[:out] = '/dev/null'
      options[:err] = '/dev/null'
    else
      print "#{cmd.first} "
      cmd[1 .. cmd.length].each {|cmd|
        if cmd.match(/[ \$'`]/)
          print %Q{"#{cmd}" }
        else
          print "#{cmd} "
        end
      }
      print "\n"
    end

    options.delete :silent

    result = Kernel.system(options[:env] || {}, *cmd, options)
    status = $?

    block.call(result, status)
  end

  def self.debug (argument, options={})
    if !System.env[:DEBUG] && !options[:force]
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

    puts output
  end

  def self.load (path, options={})
    if !File.readable? path
      raise LoadError.new("no such file to load -- #{path}")
    end

    eval("#{options[:before]}#{File.read(path, :encoding => 'utf-8').split(/^__END__$/).first}#{options[:after]}", options[:binding] || binding, path, 1)
  end

  def self.loadPackage (path, package)
    options = {
      :before => 'module ::Packo::RBuild;',
      :after  => ';end'
    }

    if File.exists?("#{path}/digest.xml") && (digest = Nokogiri::XML.parse(File.read("#{path}/digest.xml")))
      features = digest.xpath("//build[@version = '#{package.version}'][@slot = '#{package.slot}']/features").first

      if features
        features.text.split(' ').each {|feature|
          next if RBuild::Features::Default[feature.to_sym]

          begin
            Packo.load "#{System.env[:PROFILE]}/features/#{feature}", options
          rescue LoadError
          rescue Exception => e
            CLI.warn "Something went wrong while loading #{feature} feature." if System.env[:VERBOSE]
            Packo.debug e
          end
        }
      end
    end

    Packo.load "#{path}/#{package.name}.rbuild", options

    if (pkg = RBuild::Package.last) && (tmp = File.read("#{path}/#{package.name}.rbuild").split(/^__END__$/)).length > 1
      pkg.filesystem.parse(tmp.last.lstrip)
    end

    Packo.load "#{path}/#{package.name}-#{package.version}.rbuild", options

    if RBuild::Package.last.name == package.name && RBuild::Package.last.version == package.version
      RBuild::Package.last.filesystem.merge!(pkg.filesystem)

      if (tmp = File.read("#{path}/#{package.name}-#{package.version}.rbuild").split(/^__END__$/)).length > 1
        RBuild::Package.last.filesystem.parse(tmp.last.lstrip)
      end

      return RBuild::Package.last
    end
  end
end
