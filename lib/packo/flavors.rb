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

require 'packo/flavor'

module Packo

class Flavors
  attr_reader :package

  def initialize (package)
    @package = package

    @flavors = {}
  end

  def method_missing (name, *args, &block)
    if (tmp = name.to_s.match(/^(.*?)\?$/))
      (@flavors[tmp[1].to_sym] ||= Flavor.new(@package, tmp[1].to_sym, false)).enabled?
    elsif (tmp = name.to_s.match(/^(not_)?(.*?)!$/))
      @flavors[tmp[2].to_sym] ||= Flavor.new(@package, tmp[2].to_sym, false)

      if tmp[1].nil?
        @flavors[tmp[2].to_sym].enabled!
      else
        @flavors[tmp[2].to_sym].disabled!
      end
    else
      @flavors[name] = Flavor.new(@package, name, &block)
    end
  end

  def owner= (value)
    @package = value

    @flavors.each_value {|flavor|
      flavor.owner = value
    }
  end

  def to_s (pack=false)
    result = ''

    @flavors.each {|name, value|
      next if name == 'binary'

      result << name.to_s + (pack ? '.' : ',') if value.enabled?
    }

    return result[0, result.length - 1] || ''
  end
end

end
