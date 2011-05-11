#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

class Flavor
  def self.parse (text)
    data = []

    text.split(/\s+/).each {|part|
      data << Feature.parse(part)
    }

    Flavor.new(data)
  end

  def initialize (values={})
    @values = {}

    if values.is_a?(Array)
      values.dup.each {|feature|
        @values[feature.name] = feature
      }
    elsif values.is_a?(Hash)
      values.dup.each {|name, value|
        @values[name.to_sym] = Feature.new(name, value || false)
      }
    end
  end

  def each
    @values.dup.each_value {|feature|
      yield feature
    }
  end

  def empty?
    @values.empty?
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

  def has? (name)
    @values.key? name.to_sym
  end

  def to_hash
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
    values = @values.map {|(name, value)|
      next unless name != :binary && value.enabled?

      name.to_s
    }.compact

    case type
      when :normal;  values.join(' ')
      when :package; values.join('.')
    end
  end
end

end; end
