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

module Packo; module RBuild; class Stages

class Callbacks
  Chains = [:before, :after]

  class Callback
    attr_accessor :binding

    attr_reader :name, :priority, :position

    def initialize (priority, callback, binding=nil, position=nil)
      @priority = priority
      @callback = callback
      @binding  = binding
      @position = position
    end

    def call (*args)
      if binding
        binding.instance_exec(*args, &@callback)
      else
        @callback.call(*args)
      end
    end
  end

  attr_reader :name

  def initialize (name)
    @name      = name
    @callbacks = Hash[:before => [], :after => []]
    @position  = 0
  end

  def register (chain, priority, callback, binding=nil)
    @callbacks[Chains.member?(chain) ? chain : :before] << Callback.new(priority, callback, binding, @position += 1)
  end

  def sort!
    Chains.each {|chain|
      @callbacks[chain].sort! {|a, b|
        if a.priority == b.priority
          a.position <=> b.position
        else
          a.priority <=> b.priority
        end
      }
    }
  end

  def do (*args)
    self.sort!

    @callbacks[:before].each {|c| c.call(*args)}
    yield *args if block_given?
    @callbacks[:after].each {|c| c.call(*args)}
  end

  def owner= (value)
    Chains.each {|chain|
      @callbacks[chain].each {|callback|
        if callback.binding.is_a? Package
          callback.binding = value
        end
      }
    }
  end
end

end; end; end
