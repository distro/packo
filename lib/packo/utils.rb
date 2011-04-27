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

require 'ostruct'

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

  def self.load (path, options={})
    if !File.readable? path
      raise LoadError.new("no such file to load -- #{path}")
    end

    eval("#{options[:before]}#{File.read(path, encoding: 'utf-8').split(/^__END__$/).first}#{options[:after]}", options[:binding] || binding, path, 1)
  end
end
