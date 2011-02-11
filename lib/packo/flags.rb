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

module Packo

class Flags < Array
  def self.parse (string)
    Flags.new(*string.to_s.split(/\s+/))
  end

  def initialize (*flags)
    self.insert(-1, *flags)
  end

  def push (*values)
    values.each {|value|
      super(value.to_s.strip)
    }
  
    self
  end

  alias << push

  def delete (*values)
    values.each {|value|
      super(value)
    }

    self
  end

  def replace (from, to)
    self.insert(-1, *self.clear.map {|value|
      value.match(from) ? to : value
    })
  end

  def to_s
    self.join(' ')
  end
end

end
