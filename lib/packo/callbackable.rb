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

module Packo

module Callbackable
	def register (chain, name, callback, data = {})
		@callbacks ||= {}

		(@callbacks[name.to_sym] ||= Callbacks.new(name.to_sym)).register(chain, callback, data)
	end

	def unregister (chain, name, known = nil)
		@callbacks ||= {}

		(@callbacks[name.to_sym] ||= Callbacks.new(name.to_sym)).unregister(chain, known)
	end

	def callbacks (name = nil)
		@callbacks ||= {}

		if name
			@callbacks[name.to_sym] ||= Callbacks.new(name.to_sym)
		else
			@callbacks
		end
	end

	def before (name, data = {}, &block)
		register(:before, name, block, data)
	end

	def after (name, data = {}, &block)
		register(:after, name, block, data)
	end
	
	def on (name, data = {}, &block)
		register(:on, name, block, data)
	end; alias during on

	def skip (*args)
		if args.empty?
			throw :halt
		else
			chain, name, known = args

			unregister(chain, name, known)
		end
	end
end

class Callbacks
	Chains = [:before, :after]

	class Callback
		attr_reader   :name, :priority, :position
		attr_accessor :binding

		def initialize (callback, data)
			@callback = callback
			@priority = data[:priority] || 0
			@binding  = data[:binding]
			@position = data[:position] || 0
			@name     = data[:name]
		end

		def call (*args)
			if binding
				binding.instance_exec(*args, &@callback)
			else
				@callback.call(*args)
			end
		end
	end

	attr_reader :name

	def initialize (name)
		@name      = name
		@callbacks = Hash[before: [], after: [], on: []]
		@position  = 0
	end

	def register (chain, callback, data)
		@callbacks[Chains.member?(chain) ? chain : :on] << Callback.new(callback, { position: @position += 1 }.merge(data))
	end

	def unregister (chain, name = nil)
		@callbacks[Chains.member?(chain) ? chain : :on].delete_if {|callback|
			callback.name == name || name.nil?
		}
	end

	def sort!
		Chains.each {|chain|
			@callbacks[chain].sort! {|a, b|
				if a.priority == b.priority
					a.position <=> b.position
				else
					a.priority <=> b.priority
				end
			}
		}
	end

	def do (*args)
		sort!

		catch(:halt) do
			@callbacks[:before].each {|c|
				c.call(*args)
			}

			@callbacks[:on].each {|c|
				c.call(*args)
			}

			result = yield *args if block_given?

			@callbacks[:after].each {|c|
				c.call(result, *args)
			}

			result
		end
	end
end

end
