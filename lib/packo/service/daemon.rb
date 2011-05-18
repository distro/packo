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

require 'timeout'

module Packo; class Service

class Daemon
  def self.pid (id)
    if id.is_a?(String)
      id = File.read(id).to_i
    end

    require 'sys/proctable'
  
    if !Sys::ProcTable.ps(id)
      raise ArgumentError.new "PID #{id} not found"
    end

    Daemon.new(id)
  end

  def self.kill (what, signal=:INT)
    if what.is_a?(String) || what.is_a?(Regexp)
      Sys::ProcTable.ps.select {|ps|
        ps[:cmdline].match(what)
      }.map {|ps|
        ps[:pid]
      }.all? {|pid|
        Process.kill signal, pid
      }
    else
      Process.kill signal, what
    end
  end

  attr_accessor :command, :pid
  attr_reader   :data

  def initialize (what)
    @data = OpenStruct.new

    if what.is_a?(Integer)
      @pid     = what
      @command = Sys::ProcTable.ps(@pid)[:cmdline]
    else
      @command = what.to_s
    end

    yield @data, self if block_given?
  end
  
  def send (name)
    Process.kill(name, @pid) if @pid
  end

  def start (*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    
    r, w = IO.pipe

    pid = Process.spawn(@command, *args, {
      STDERR => w,
      STDOUT => w
    })

    if options[:detach]
      Process.detach(pid)
      w.close
    else
      Process.wait(pid)
      w.close

      if $?.to_i != 0
        raise RuntimeError.new r.read
      end
    end

    if options[:save] != false
      File.write(@data.pid || "/var/run/#{File.basename(@command)}.pid", pid)
    end

    pid
  end

  def stop
    Timeout.timeout(5) {
      self.send(:INT)

      Process.wait(@pid)
    } rescue false
  end
end

end; end
