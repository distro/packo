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

require 'dm-core'
require 'dm-constraints'
require 'dm-migrations'
require 'dm-types'

require 'packo/fixes'
require 'packo/environment'
require 'versionomy'

module DataMapper

if Packo::Environment[:DEBUG].to_i > 0
  Logger.new($stdout, :debug)
end

Model.raise_on_save_failure = true

class Property
  class Version < String
    # Hopefully the max length of a version won't go over 255 chars
    length 255

    def custom?
      true
    end

    def primitive? (value)
      value.is_a?(Versionomy::Value)
    end

    def valid? (value, negated = false)
      super || primitive?(value) || value.is_a?(::String)
    end

    def load (value)
      Versionomy.parse(value.to_s) unless value.to_s.empty?
    end

    def dump (value)
      value.to_s unless value.nil?
    end

    def typecast_to_primitive (value)
      load(value)
    end
  end
end

setup :default, Packo::Environment[:DATABASE]

require 'packo/models/installed_package'
require 'packo/models/repository'

finalize

auto_upgrade!

end
