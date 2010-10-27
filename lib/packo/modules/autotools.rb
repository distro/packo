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

      @flags = {}
    end

    def enable (name)
      set name, true
    end

    def disable (name)
      set name, false
    end

    def set (name, value)
      @flags[name] = value
    end

    def to_s
      result = ''

      @flags.each {|name, value|
        case value
          when true
            result += "--enable-#{name} "

          when false
            result += "--disable-#{name} "

          else
            result += "--width-#{name}=#{value}"
        end
      }

      return result
    end
  end

  def initialize (package)
    super(package)

    package.stages.add :configure, { :before => :fetched }, self.method(:configure)
  end

  def configure
    configuration = Configuration.new(self)

    package.stages.call :configure, configuration
  end
end

end

end
