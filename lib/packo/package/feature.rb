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

module Packo; class Package

class Feature
	def self.parse (text)
		whole, name, value = text.match(/^[\+\-]?(.*)(?:=(.*?))?$/).to_a

		Feature.new(name, value ? value : !text.start_with?('-'))
	end

	attr_reader :name

	def initialize (name, value = false, description = nil)
		@name        = name.to_sym
		@value       = value if value.is_a? String
		@enabled     = !!value
		@description = description
	end

	def value (value = nil)
		if value
			@value = value
		elsif enabled?
			@value || @default_value
		else
			@value
		end
	end

	def default_value (value = nil)
		value ? @default_value = value : @default_value
	end

	def enabled?;   @enabled                        end
	def disabled?; !@enabled                        end
	def enabled!;   @enabled = true  unless @forced end
	def disabled!;  @enabled = false unless @forced end
	def enable!;    @enabled = true  unless @forced end
	def disable!;   @enabled = false unless @forced end

	def forced?;     @forced         end
	def force!;      @forced = true  end
	def not_forced!; @forced = false end

	def description (value = nil)
		value ? @description = value : @description
	end

	def to_sym
		@name
	end

	def to_s
		to_sym.to_s
	end
end

end; end
