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

require 'packo/stage'

module Packo

class Stages
  def self.max; 23 end

  attr_reader :package, :stages, :callbacks

  def initialize (package)
    @package = package

    @stages    = []
    @callbacks = {}
  end

  def add (name, method, options={})
    @stages.delete_if {|stage|
      stage.name == name
    }

    @stages << Stage.new(name, method, options)

    @sorted = false
  end

  # Ugly incomprensibile shit ahead. It's dangerous to go alone! Take this! <BS>
  #
  # In short it tries to sort stuff as it wanted to be placed depending on stage's options
  def sort! (strict=false)
    if @sorted
      return false
    end

    if strict
      @stages.select {|stage|
        stage.options[:strict]
      }.each {|stage|
        @stages.delete(stage)

        if target = stage.options[:at]
          if target == :beginning
            @stages.unshift stage
          elsif target == :end
            @stages.push stage
          end
        elsif stage.options[:before]
          if (index = @stages.find_index {|s| s.name == stage.options[:before]})
            @stages.insert(index, @stages.delete(stage))
          end
        elsif stage.options[:after]
          if (index = @stages.find_index {|s| s.name == stage.options[:after]})
            @stages.insert(index + 1, old.delete(stage))
          end
        else
          if index = @stages.reverse.find_index {|s| s.options[:at] == :beginning} || @stages.length + 1
            @stages.insert(@stages.length - index + 1, old.delete(stage))
          end
        end
      }
    else
      old, @stages, cycles = @stages, [], 0

      while old.length > 0 && cycles < Stages.max
        old.clone.each {|stage|
          if target = stage.options[:at]
            if target == :beginning
              @stages.unshift stage
            elsif target == :end
              @stages.push stage
            end

            old.delete(stage)
          elsif stage.options[:before]
            if (index = @stages.find_index {|s| s.name == stage.options[:before]})
              @stages.insert(index, old.delete(stage))
              old.delete(stage)
            end
          elsif stage.options[:after]
            if (index = @stages.find_index {|s| s.name == stage.options[:after]})
              @stages.insert(index + 1, old.delete(stage))
              old.delete(stage)
            end
          else
            index = @stages.reverse.find_index {|s| s.options[:at] == :beginning} || @stages.length + 1
            @stages.insert(@stages.length - index + 1, old.delete(stage))
            old.delete(stage)
          end
        }

        cycles += 1
      end

      self.sort!(true)

      old
    end

    @sorted = true
  end

  def each (&block)
    self.sort!

    @stages.each {|stage|
      block.call stage
    }
  end

  def register (what, callback)
    (@callbacks[what.to_sym] ||= []) << callback
  end

  def call (what, *args)
    result = []

    (@callbacks[what.to_sym] ||= []).each {|callback|
      begin
        result << callback.call(*args)
      rescue Exception => e
        result << e
      end
    }

    return result
  end
end

end
