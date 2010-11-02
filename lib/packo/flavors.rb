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

    @names = [:binary, :headers, :documentation, :debug, :minimal, :vanilla]

    @values = {
      :headers => true,
      :documentation => true
    }

    @callbacks = {}
  end

  def method_missing (name, *args, &block)
    if (tmp = name.match(/^(.*?)\?$/))
      @values[tmp[1].to_sym]
    elsif (tmp = name.match(/^(not_)?(.*?)\?$/))
      @values[tmp[2].to_sym] = !tmp[2]
    else
      @values[name]    = true
      @callbacks[name] = block
    end
  end

  def to_s (pack=false)
    result = ''

    @values.each {|name, value|
      result << name.to_s + (pack ? '.' : ',') if value
    }

    return result[0, result.length - 1]
  end
end

end
