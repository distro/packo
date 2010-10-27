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

require 'packo/package/flavor'

module Packo

class Package

class Flavors
  attr_reader :package

  def initialize (package)
    @package = package
    @flavors = {}
  end

  def method_missing (id, *args, &block)
    @flavors[id] = Flavor.new(@package, id, &(block || proc {}))
  end

  def inspect
    @flavors.sort {|a, b|
      if a[1].enabled? && b[1].enabled?
        0
      elsif a[1].enabled? && !b[1].enabled?
        -1
      else
        1
      end
    }.to_a.map {|flavor| (flavor[1].enabled? ? '' : '-') + flavor[0].to_s}.join(' ')
  end
end

end

end
