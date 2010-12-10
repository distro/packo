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
require 'versionomy'
require 'ostruct'

require 'packo/extensions'
require 'packo/system'

module Packo
  VERSION = Versionomy.parse('0.0.1')

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

  def self.colorize (text, fg, bg=nil, attr=nil)
    return text if System.env[:NO_COLORS]

    colors = {
      :DEFAULT => 9,
      nil      => 9,

      :BLACK   => 0,
      :RED     => 1,
      :GREEN   => 2,
      :YELLOW  => 3,
      :BLUE    => 4,
      :MAGENTA => 5,
      :CYAN    => 6,
      :WHITE   => 7
    }

    attributes = {
      :DEFAULT => 0,
      nil      => 0,

      :BOLD      => 1,
      :UNDERLINE => 4,
      :BLINK     => 5,
      :REVERSE   => 7
    }

    "\e[#{attributes[attr]};3#{colors[fg]};4#{colors[bg]}m#{text}\e[0m"
  end

  def self.info (text)
    puts "#{colorize('*', :GREEN, :DEFAULT, :BOLD)} #{text}"
  end

  def self.warn (text)
    puts "#{colorize('*', :YELLOW, :DEFAULT, :BOLD)} #{text}"
  end

  def self.fatal (text)
    puts "#{colorize('*', :RED)} #{text}"
  end
end

require 'packo/models'
