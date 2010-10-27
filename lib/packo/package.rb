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

require 'packo/stages'
require 'packo/package/flavors'

module Packo

class Package
  attr_reader :name, :categories, :version, :modules, :flavors, :stages, :data

  def initialize (name, version=nil, &block)
    tmp         = name.split('/')
    @name       = tmp.pop
    @categories = tmp
    @version    = version

    @modules = []
    @stages  = Packo::Stages.new(self)
    @flavors = Packo::Package::Flavors.new(self)
    @data    = {}

    self.instance_exec(self, &block) if block
  end

  def build
    @stages.stages.each {|stage|
      stage.call      
    }
  end

  def use (klass)
    @modules << klass.new(self)
  end

  def flavors (&block)
    @flavors.instance_eval &block
  end

  def on (what, &block)
    @stages.register(what, block)
  end

  def method_missing (id, *args)
    if args.length == 0
      return @data[id]
    else
      @data[id] = ((args.length > 1) ? args : args.first)
    end
  end

  def inspect
    "#{(@categories + [@name]).join('/')}#{"-#{@version}" if @version} {#{@flavors.inspect}}"
  end
end

end
