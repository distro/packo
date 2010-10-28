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

require 'ostruct'

require 'packo/dependencies'
require 'packo/stages'
require 'packo/flavors'

module Packo

class Package
  @@roots = {}

  def self.parse (text)
    result = OpenStruct.new

    matches = text.match(/^(.*?)(\[(.*?)\])?$/)

    result.flavors = Hash[(matches[3] || '').split(/\s*,\s*/).map {|flavor|
      if flavor[0] == '-'
        [flavor[1, flavor.length], false]
      else
        [(flavor[0] == '+' ? flavor[1, flavor.length] : flavor), true]
      end
    }]

    matches = matches[1].match(/^(.*?)(-(\d.*))?$/)

    tmp               = matches[1].split('/')
    result.name       = tmp.pop
    result.categories = tmp

    result.version = matches[3]

    return result
  end

  attr_reader :name, :categories, :version, :modules, :dependencies, :flavors, :stages, :data

  def initialize (name, version=nil, &block)
    tmp         = name.split('/')
    @name       = tmp.pop
    @categories = tmp
    @version    = version

    if !version
      @@roots[(@categories + [@name]).join('/')] = self
    end

    if !version || !(tmp = @@roots[(@categories + [@name]).join('/')])
      @modules      = []
      @dependencies = Packo::Dependencies.new(self)
      @stages       = Packo::Stages.new(self)
      @flavors      = Packo::Flavors.new(self)
      @data         = {}
    else
      @modules      = tmp.instance_eval('@modules.clone')
      @dependencies = tmp.instance_eval('@dependencies.clone')
      @stages       = tmp.instance_eval('@stages.clone')
      @flavors      = tmp.instance_eval('@flavors.clone')
      @data         = tmp.instance_eval('@data.clone')

      package = self

      @modules.each {|mod|
        mod.instance_eval('@package = package')
      }

      @dependencies.instance_eval('@package = package')

      @flavors.instance_eval('@package = package')

      @flavors.each {|flavor|
        flavor.instance_eval('@package = package')
      }
    end

    @stages.add :dependencies, @dependencies.method(:check), :at => :beginning

    self.instance_exec(self, &block) if block
  end

  def build
    @stages.each {|stage|
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
      @data[id] = args
    end
  end

  def inspect
    tmp = @flavors.inspect

    "#{(@categories + [@name]).join('/')}#{"-#{@version}" if @version}#{"[#{tmp}]" if !tmp.empty?}"
  end
end

end
