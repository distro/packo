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

module Packo; class Package

class Flavor
  Names = [:binary, :vanilla, :headers, :documentation, :minimal, :debug]

  class Element
    attr_reader :name, :value

    def initialize (name, enabled=false)
      @name    = name.to_sym
      @enabled = !!enabled
    end

    def enabled?; @enabled         end
    def enable!;  @enabled = true  end
    def disable!; @enabled = false end
  end

  def self.parse (text)
    data = {}

    text.split(/\s+/).each {|part|
      if (matches = part.match(/([\+\-])?(.+)/))
        data[matches[2].to_sym] = (matches[1] != '-')
      end
    }

    Flavor.new(data)
  end

  def initialize (values={})
    @elements = {}

    Names.each {|name|
      @elements[name] = Element.new(name, values[name] || false)
    }
  end

  def to_h
    Hash[*@elements.map {|(name, element)|
      [name, element.value]
    }]
  end

  def to_a
    @elements.map {|(name, element)|
      element
    }
  end

  def to_s (type=:normal)
    elements = @elements.map {|(name, element)|
      next if name == :binary || !element.enabled?

      name.to_s if element.enabled?
    }.compact

    case type
      when :normal; elements.join(', ')
      when :pack;   elements.join('.')
    end
  end
end

Flavor::Names.each {|name|
  Flavor.class_eval("def #{name};      @elements[:#{name}]          end")
  Flavor.class_eval("def #{name}?;     @elements[:#{name}].enabled? end")
  Flavor.class_eval("def #{name}!;     @elements[:#{name}].enable!  end")
  Flavor.class_eval("def not_#{name}!; @elements[:#{name}].disable! end")
}

end; end
