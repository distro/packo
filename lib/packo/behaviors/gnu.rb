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

require 'packo/modules/fetching/wget'
require 'packo/modules/misc/unpack'
require 'packo/modules/building/patch'
require 'packo/modules/building/autotools'
require 'packo/modules/packaging/pko'

module Packo

module Behaviors

GNU = [
	Packo::Modules::Fetching::Wget, Packo::Modules::Misc::Unpack,
	Packo::Modules::Building::Patch, Packo::Modules::Building::Autotools,
	Packo::Modules::Packaging::PKO
]

end

end
