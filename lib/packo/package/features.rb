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

require 'packo/package/feature'

module Packo; class Package

class Features
  def self.parse (text)
    data = {}

    text.split(/\s+/).each {|part|
      if (matches = part.match(/([\+\-])?(.+)/))
        data[matches[2].to_sym] = (matches[1] != '-')
      end
    }

    self.new(data)
  end

  def initialize (values={})
    @values = {}

    values.each {|name, value|
      @values[name.to_sym] = Feature.new(name, value || false)
    }
  end

  def each
    @values.each_value {|f|
      yield f
    }
  end

  def set (name, value)
    @values[name.to_sym] = Feature.new(name, value)
  end

  def get (name)
    @values[name.to_sym] ||= Feature.new(name, false)
  end

  def delete (name)
    @values.delete(name.to_sym)
  end

  def has (name)
    @values.key? name
  end

  def to_h
    Hash[*@values.map {|(name, element)|
      [name, element.value]
    }]
  end

  def to_a
    @values.map {|(name, element)|
      element
    }
  end

  def to_s (type=:normal)
    case type
      when :pack
        @values.select {|name, feature| feature.enabled?}.map {|item| item[0]}.join('-')
  
      when :normal
        @values.sort {|a, b|
          if a[1].enabled? && b[1].enabled?     then  0
          elsif a[1].enabled? && !b[1].enabled? then -1
          else                                        1
          end
        }.to_a.map {|feature|
          (feature[1].enabled? ? '' : '-') + feature[0].to_s
        }.join(',')
    end
  end
end

end; end
