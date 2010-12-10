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
  def self.write (path, content, *args)
    file = File.new(path, 'w', *args)
    file.write(content)
    file.close
  end
end

class String
  def interpolate (on)
    on.instance_eval("%{#{self}}") rescue self
  end

  alias __old_equal ===

  def === (value)
    value.is_a?(Packo::Host) ?
      value == self :
      __old_equal(value)
  end
end

class OpenStruct
  alias to_hash marshal_dump
end
