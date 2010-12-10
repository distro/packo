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

module Packo; module RBuild

class Flavor < Packo::Package::Flavor
  class Element < Packo::Package::Flavor::Element
    include Stages::Callable

    attr_reader :package

    def initialize (package, name, enabled=false, &block)
      super(name, enabled)

      @package = package

      self.instance_exec(self, &block) if block
    end

    def execute (&block)
      self.instance_exec(self, &block) if block; self
    end

    def method_missing (id, *args, &block)
      @package.send id, *args, &block
    end

    def owner= (value)
      @package = value
    end
  end

  attr_reader :package

  def initialize (package, values={})
    @package  = package
    @elements = {}

    values.each {|name, value|
      @elements[name.to_sym] = Element.new(package, name, value || false)
    }
  end

  def method_missing (id, *args, &block)
    case id.to_s
      when /^(.+?)\?$/    then (@elements[$1.to_sym] ||= Element.new(@package, $1, false)).enabled?
      when /^not_(.+?)!$/ then (@elements[$1.to_sym] ||= Element.new(@package, $1, false)).disable!
      when /^(.+?)!$/     then (@elements[$1.to_sym] ||= Element.new(@package, $1, false)).enable!
      when /^(.+?)$/      then (@elements[$1.to_sym] ||= Element.new(@package, $1, false)).execute(&block)
    end
  end

  def owner= (value)
    @package = value

    @elements.each_value {|element|
      element.owner = value
    }
  end
end

end; end
