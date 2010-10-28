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

require 'packo/module'

module Packo

module Modules

class Autotools < Module
  class Configuration
    attr_reader :module

    def initialize (mod)
      @module = mod

      @enable = {}
      @with   = {}
    end

    def with (name, value=nil)
      [name].flatten.each {|name|
        if value === true || value === false
          @with[name.to_s] = value
        else
          @with[name.to_s] = value || true
        end
      }
    end

    def without (name, value=nil)
      [name].flatten.each {|name|
        if value === true || value === false
          @with[name.to_s] = !value
        else
          @with[name.to_s] = false
        end
      }
    end

    def enable (name, value=nil)
      [name].flatten.each {|name|
        if value === true || value === false
          @enable[name.to_s] = value
        else
          @enable[name.to_s] = value || true
        end
      }
    end

    def disable (name, value=nil)
      [name].flatten.each {|name|
        if value === true || value === false
          @with[name.to_s] = !value
        else
          @with[name.to_s] = false
        end
      }
    end

    def to_s
      result = ''

      @enable.each {|name, value|
        case value
          when true;  result += "--enable-#{name} "
          when false; result += "--disable-#{name} "
          else;       result += "--enable-#{name}=#{value} "
        end
      }

      @with.each {|name, value|
        case value
          when true;  result += "--with-#{name} "
          when false; result += "--without-#{name} "
          else;       result += "--with-#{name}=#{value} "
        end
      }

      return result
    end
  end

  def initialize (package)
    super(package)

    package.stages.add :configure, self.method(:configure), :after => :fetched
    package.stages.add :compile, self.method(:compile), :after => :configure
  end

  def configure
    configuration = Configuration.new(self)

    package.stages.call :configure, configuration

    puts configuration.inspect
  end

  def compile
    package.stages.call :compile
  end
end

end

end
