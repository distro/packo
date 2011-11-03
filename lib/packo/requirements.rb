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

require 'packo/system'

class Numeric
	module Scalar
		Multipliers = ['', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y']

		Multipliers.each {|key|
			define_method "#{key}B" do
				self * (1024 ** Multipliers.index(key))
			end
		}
	end
end

class Integer
	include Numeric::Scalar
end

class Float
	include Numeric::Scalar
end

class Rational
	include Numeric::Scalar
end

require 'packo/os'

module Packo

class Requirements
	def self.disk (path=nil, option)
		return false if !(stat = OS::Filesystem.stat(path))

		return false if options[:free] && stat.free < options[:free]

		return false if options[:total] && stat.total < options[:total]

		true
	end

	def self.memory (options={})
		status = OS::Ram.status

		case options[:type]
			when :physycal, :phys, :phy
				return false if options[:free] && status.physical.free < options[:free]

				return false if options[:total] && total.physical.total < options[:total]

			when :swap
				return false if options[:free] && status.swap.free < options[:free]

				return false if options[:total] && total.swap.total < options[:total]

			else
				return false if options[:free] && status.virtual.free < options[:free]

				return false if options[:total] && total.virtual.total < options[:total]
		end

		true
	end
end

end
