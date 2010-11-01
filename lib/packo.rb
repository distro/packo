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

require 'fileutils'

module Packo
  def self.env (name, value=nil)
    if value.nil?
      return ENV["PACKO_#{name}"] || ENV[name.to_s]
    else
      ENV["PACKO_#{name}"] = value.to_s
    end
  end

  def self.interpolate (string, on)
    on.instance_eval('"' + string + '"') rescue nil
  end

  def self.sh (*cmd, &block)
    options = (Hash === cmd.last) ? cmd.pop : {}

    if !block_given?
      show_command = cmd.join(' ')
      show_command = show_command[0, 42] + '...' unless $trace

      block = lambda {|ok, status|
        ok or fail "Command failed with status (#{status.exitstatus}): [#{show_command}]"
      }
    end

    print "#{cmd.first} "
    cmd[1 .. cmd.length].each {|cmd|
      if cmd.match(/[ ']/)
        print %Q{"#{cmd}" }
      else
        print "#{cmd} "
      end
    }
    print "\n"

    result = Kernel.system(options[:env] || {}, *cmd, options)
    status = $?

    block.call(result, status)
  end

  def self.debug (argument, options={})
    if !Packo.env('DEBUG')
      return
    end

    if Packo.env('DEBUG').to_i < (options[:level] || 1)
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
end

require 'packo/package'
