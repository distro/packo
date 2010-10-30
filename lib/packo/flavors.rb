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

    @binary        = false
    @headers       = true
    @documentation = true
    @debug         = false
    @minimal       = false
  end

  def binary?;        @binary        end
  def headers?;       @headers       end
  def documentation?; @documentation end
  def debug?;         @debug         end
  def minimal?;       @minimal       end

  def binary!;        @binary        = true end
  def headers!;       @headers       = true end
  def documentation!; @documentation = true end
  def debug!;         @debug         = true end
  def minimal!;       @minimal       = true end

  def not_binary!;        @binary        = false end
  def not_headers!;       @headers       = false end
  def not_documentation!; @documentation = false end
  def not_debug!;         @debug         = false end
  def not_minimal!;       @minimal       = false end

  def to_s (pack=false)
    result = ''

    ['binary', binary?, 'headers', headers?, 'documentation', documentation?, 'debug', debug?, 'minimal', minimal?].each_slice(2) {|flavor|
      result << flavor[0] + (pack ? '.' : ',') if flavor[1]
    }

    return result[0, result.length - 1]
  end
end

end
