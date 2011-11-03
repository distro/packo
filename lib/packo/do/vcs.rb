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

require 'packo/rbuild'

module Packo; class Do

class VCS
	def self.checkout (location, path)
		require 'packo/rbuild'

		location = Location[location]

		if RBuild::Modules::Fetching.const_defined?(location.type.capitalize)
			RBuild::Modules::Fetching.const_get(location.type.capitalize).fetch(location, path)
		else
			raise ArgumentError, "#{location.type} is an unsupported SCM"
		end
	end

	def self.update (location, path)
		require 'packo/rbuild'

		location = Location[location]

		if RBuild::Modules::Fetching.const_defined?(location.type.capitalize)
			RBuild::Modules::Fetching.const_get(location.type.capitalize).update(path)
		else
			raise ArgumentError, "#{location.type} is an unsupported SCM"
		end
	end
end

end; end
