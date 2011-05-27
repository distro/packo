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

module Packo; class Do; class Repository

class Model
  def self.add (type, name, location, path, populate=true)
    require 'packo/models'

    repo = Helpers::Repository.wrap(Models::Repository.create(
      :type => type,
      :name => name,

      :location => location,
      :path =>     path
    ))

    repo.populate if populate

    repo
  end

  def self.delete (type, name)
    require 'packo/models'

    Models::Repository.first(:name => name, :type => type).destroy
  end
end

end; end; end
