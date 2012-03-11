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

require 'packo'
require 'packo/os'
require 'packo/callbackable'

require 'packo/service/cli'
require 'packo/service/daemon'

module Packo

class Service
	Paths = %w(/sbin/rc.d /sbin/init.d /etc/init.d)

	def self.all
		Paths.map {|path|
			Dir["#{path}/*"]
		}.flatten.map {|service|
			path = Service.path(service)

			Class.new {
				attr_reader :path

				def initialize (path)
					@path = path
				end

				def method_missing (id, *args, &block)
					if id.to_s.end_with?('?')
						Packo.sh(path, :status, catch: true).strip.include?(id.to_s[0 .. -2])
					elsif id.to_s.end_with?('!')
						Packo.sh(path, id.to_s[0 .. -2], *args)
					else
						super
					end
				end
			}.new(path)
		}
	end

	def self.path (name)
		return if name.start_with?('/') && File.executable(name)

		path = Paths.find {|path|
			File.executable?("#{path}/#{name}")
		} or return

		"#{path}/#{name}"
	end

	def self.current
		@current
	end

	def self.define (options={}, &block)
		@current = Service.new(options, &block)
	end

	def self.start (name, options={})
		service = Service.path(name) or return false

		Packo.sh service, :start, options

		started?(name)
	end

	def self.stop (name)
		service = Service.path(name) or return false

		Packo.sh service, :stop

		stopped?(name)
	end

	def self.started? (name)
		Packo.sh(Service.path(name), :status, catch: true).strip.end_with('started')
	end

	def self.stopped? (name)
		Packo.sh(Service.path(name), :status, catch: true).strip.end_with('stopped')
	end

	include Callbackable

	attr_reader :options, :configuration

	alias config configuration
	alias conf   configuration

	def initialize (options={}, &block)
		@options = options
		@blocks  = {}

		@configuration ||= options[:configuration] || {}

		instance_eval &block if block

		self
	end

	%w(it this).each {|name|
		define_method name do
			self
		end
	}

	def needs (*args)
		args.flatten!
		args.compact!

		args.empty? ? (@needs || []) : @needs = args
	end

	def is (name, what={})
		start do
			CLI.warn "#{name} is already started" and next if started?

			daemon = Daemon.new(what[:command].shellsplit.first) {|d|
				d.pid = config['pid'] || Daemon.pid_file_for(name)
			}

			CLI.message "Starting #{name}..." do
				daemon.start(*what[:command].shellsplit[1 .. -1].compact, what[:options] || {})
			end
		end

		stop do
			CLI.warn "#{name} is already stopped" and next if stopped?

			daemon = Daemon.pid(config['pid'] || Daemon.pid_file_for(name))

			CLI.message "Stopping #{name}..." do
				daemon.stop || daemon.stop(force: true)
			end
		end

		status do
			daemon = Daemon.pid(config['pid'] || Daemon.pid_file_for(name))

			if daemon
				puts "started"
			else
				puts "stopped"
			end
		end
	end

	def supervised?
		!!System.env[:INIT_SUPERVISED]
	end

	def method_missing (id, *args, &block)
		return super(id, *args) unless block

		@blocks[id] = block
	end

	def run (*args)
		args.flatten!

		if args.length == 0
			if @options[:help]
				puts @options[:help]
			else
				puts "#{$0} start|stop|restart|status"
			end

			return
		end

		block = @blocks[command = args.shift.to_sym]

		if command == :start
			needs.each {|need|
				if need.start_with? '!'
					if Service.started?(need[1 .. -1])
						raise RuntimeError, "#{@options[:name] || 'this service'} can't run at the same time with #{need[1 .. -1]}"
					end
				else
					if !Service.start(need)
						raise RuntimeError, "could not start #{need}"
					end
				end
			}
		elsif command == :restart && !block
			block = Proc.new {
				run :stop and run :start
			}
		else
			if !block
				CLI.fatal "#{@options[:name] || 'This service'} doesn't know how to do this"
				puts @options[:help] if @options[:help]

				return
			end
		end

		callbacks(command).do {
			block.call(args) if block
		}
	end

	def started?
		catch_output {
			run(:status)
		}.include?('started')
	end

	def stopped?
		catch_output {
			run(:status)
		}.include?('stopped')
	end
end

end
