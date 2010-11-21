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

    def enabled?;  @enabled         end
    def enabled!;  @enabled = true  end
    def disabled!; @enabled = false end
  end

  def self.parse (text)
    data = {}

    text.split(/\s+/).each {|part|
      matches = part.match(/([\+\-])(.+)/)

      data[matches[2].to_sym] = matches[1] != '-'
    }

    Flavor.new(data)
  end

  def initialize (values)
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
end

Flavor::Names.each {|name|
  Flavor.define_method "#{name}?" do
    @elements[name]
  end

  Flavor.define_method "#{name}!" do
    @elements[name].enable!
  end

  Flavor.define_method "not_#{name}!" do
    @elements[name].disable!
  end
}

end; end
