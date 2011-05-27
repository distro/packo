 #--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free :software => you can redistribute it and/or modify
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

require 'packo/models/repository/package/source/feature'
require 'packo/models/repository/package/source/flavor'

module Packo; module Models; class Repository; class Package

class Source
  include DataMapper::Resource

  belongs_to :package, :key => true

  property :path, Text, :default => ''

  has n, :features, :constraint => :destroy
  has n, :flavor,   :constraint => :destroy
end

end; end; end; end
