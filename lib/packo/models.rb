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

require 'packo/environment'

require 'dm-core'
require 'dm-constraints'
require 'dm-migrations'
require 'dm-types'

if Packo::Environment[:DEBUG].to_i > 0
  DataMapper::Logger.new($stdout, :debug)
end

DataMapper::Model.raise_on_save_failure = true

class DataMapper::Model
  def self.create_or_replace (stuff)
    obj = self.first_or_new(stuff)
    obj.update(stuff)
    obj
  end
end


DataMapper.setup(:default, Packo::Environment[:DATABASE])

require 'packo/models/main'
require 'packo/models/repository'

DataMapper.finalize

DataMapper.auto_upgrade!
