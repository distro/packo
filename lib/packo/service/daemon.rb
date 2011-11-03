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
require 'packo/os'

module Packo; class Service

class Daemon
	def self.pid_file_for (name)
		"/var/run/#{name}.pid"
	end

	def self.pid (id)
		file = nil

		if id.is_a?(String)
			return unless File.readable?(id)

			file, id = id, File.read(id).to_i
		end

		if !OS::Process.from_id(id)
			return
		end

		Daemon.new(id) {|d|
			d.pid = file
		}
	end

	attr_reader :process, :data

	def initialize (what)
		@data = OpenStruct.new

		if what.is_a?(Integer)
			@process = OS::Process.from_id(what)
		else
			@command = what.to_s
		end

		yield @data, self if block_given?

		if !@data.pid
			@data.pid = "/var/run/#{File.basename(@command || @process.command)}.pid"
		end
	end
	
	def send (name)
		@process.send(name)
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
		else
			Process.wait(pid)
		end

		w.close

		if !options[:detach] && $?.to_i != 0
			raise RuntimeError.new r.read
		end

		if options[:detach]
			File.write(@data.pid || Daemon.pid_file_for(@command || @process.command), pid)
		else
			Timeout.timeout(options[:wait] || 5) {
				while !(pid = File.read(@data.pid).to_i rescue nil)
					sleep 0.5
				end
			} rescue nil
		end

		@process = OS::Process.from_id(pid) if pid
	end

	def stop (options = {})
		Timeout.timeout(options[:timeout] || 10) {
			@process.kill(options[:force])
		} rescue false
	end
end

end; end
