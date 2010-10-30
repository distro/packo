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

class Flavors
  attr_reader :package

  def initialize (package)
    @package = package

    Packo.env('FLAVOR', 'headers documentation') if !Packo.env('FLAVOR')
  end

  def binary?;        !!Packo.env('FLAVOR').include?('binary')        end
  def headers?;       !!Packo.env('FLAVOR').include?('headers')       end
  def documentation?; !!Packo.env('FLAVOR').include?('documentation') end
  def debug?;         !!Packo.env('FLAVOR').include?('debug')         end
  def minimal?;       !!Packo.env('FLAVOR').include?('minimal')       end

  def to_s (pack=false)
    result = ''

    ['binary', binary?, 'headers', headers?, 'documentation', documentation?, 'debug', debug?, 'minimal', minimal?].each_slice(2) {|flavor|
      result << flavor[0] + (pack ? '.' : ',') if flavor[1]
    }

    return result[0, result.length - 1]
  end
end

end
