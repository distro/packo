#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

require 'packo/extensions'
require 'digest/sha1'
require 'fileutils'

module Packo
  def self.protected?
    !!(ENV['SANDBOX_ACTIVE'] || ENV['FAKED_MODE'])
  end

  def self.user?
    ENV['USER'] != 'root'
  end

  def self.sh (*cmd, &block)
    options = (Hash === cmd.last) ? cmd.pop : {}
    cmd     = cmd.flatten.compact.map {|c| c.to_s}

    if !block_given?
      show_command = cmd.join(' ')
      show_command = show_command[0, 42] + '...' unless $trace

      block = lambda {|ok, status|
        ok or fail "Command failed with status (#{status.exitstatus}): [#{show_command}] in {#{Dir.pwd}}"
      }
    end

    if options[:silent] || options[:catch]
      r, w = IO.pipe

      options[:out] = w
      options[:err] = w
    else
      print "#{cmd.first} "
      cmd[1 .. cmd.length].each {|cmd|
        print cmd.shellescape
        print ' '
      }
      print "\n"
    end

    options.delete :silent

    result = Kernel.system(options[:env] || {}, *cmd, options)
    status = $?

    block.call(result, status)

    if options[:catch]
      r.read
    else
      status
    end
  end

  def self.load (path, options={})
    if !File.readable? path
      raise LoadError.new("no such file to load -- #{path}")
    end

    eval("#{options[:before]}#{File.read(path, encoding: 'utf-8').split(/^__END__$/).first}#{options[:after]}", options[:binding] || binding, path, 1)
  end

  def self.digest (path)
    Digest::SHA1.hexdigest(File.read(path))
  end

  def self.contents (obj, &block)
    Enumerator.new do |e|
      obj.each {|file|
        next unless File.directory?(file) || File.symlink?(file) || File.file?(file)

        data = {}
        data.merge!(block.call(file) || {}) if block

        next if data[:next]

        data[:source] ||= file
        data[:path]   ||= file

        if File.directory?(file)
          data[:type] ||= :dir
        elsif File.symlink?(file)
          data[:type] ||= :sym
          data[:meta] ||= File.readlink(file)
        elsif File.file?(file)
          data[:type] ||= :obj
          data[:meta] ||= Packo.digest(file)
        end

        e << OpenStruct.new(data)
      }
    end
  end
end
