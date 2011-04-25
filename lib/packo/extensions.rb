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

require 'ostruct'

class Object
  def numeric?
    true if Float(self) rescue false
  end
end

module Kernel
  def suppress_warnings
    tmp, $VERBOSE = $VERBOSE, nil

    result = yield

    $VERBOSE = tmp

    return result
  end
end

class File
  def self.write (path, data, mode=nil)
    open(path, 'wb') {|f|
      f.write data
      f.chmod mode if mode
    }
  end

  def self.append (path, data, mode=nil)
    open(path, 'ab') {|f|
      f.write data
      f.chmod mode if mode
    }
  end
end

class String
  def interpolate (on)
    on.instance_eval("%{#{self}}") rescue self
  end

  def === (value)
    value.is_a?(Packo::Host) ?
      value == self :
      super(value)
  end
end

class OpenStruct
  alias to_hash marshal_dump
end
