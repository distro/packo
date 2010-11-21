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

require 'packo/stages/stage'
require 'packo/stages/callback'

module Packo

class Stages
  @@cycles = 23

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
      stages = @stages.select {|stage|
        stage.options[:strict]
      }
      
      stages.each {|stage|
        if (!stage.options[:before] && !stage.options[:after]) || stage.options[:before] == :end || stage.options[:after] == :beginning
          next
        end

        @stages.delete(stage)

        if stage.options[:before]
          if (index = @stages.find_index {|s| s.name == stage.options[:before]})
            @stages.insert(index, stage)
          end
        elsif stage.options[:after]
          if (index = @stages.find_index {|s| s.name == stage.options[:after]})
            @stages.insert(index + 1, stage)
          end
        end
      }

      stages.each {|stage|
        if !stage.options[:at]
          next
        end

        @stages.delete(stage)

        if stage.options[:at] == :beginning
          @stages.unshift stage
        elsif stage.options[:at] == :end
          @stages.push stage
        end
      }

      stages.each {|stage|
        if stage.options[:before] != :end && stage.options[:after] != :beginning
          next
        end

        @stages.delete(stage)

        if stage.options[:after] == :beginning
          index = @stages.reverse.find_index {|s| s.options[:at] == :beginning} || @stages.length + 1
          @stages.insert(@stages.length - index, stage)
        elsif stage.options[:before] == :end
          index = @stages.find_index {|s| s.options[:at] == :end} || @stages.length
          @stages.insert(index, stage)
        end
      }
    else
      old, @stages, cycles = @stages, [], 0

      while old.length > 0 && cycles < @@cycles
        old.clone.each {|stage|
          if target = stage.options[:at]
            if target == :beginning
              @stages.unshift stage
            elsif target == :end
              @stages.push stage
            end

            old.delete(stage)
          elsif stage.options[:before] && stage.options[:before] != :end
            if (index = @stages.find_index {|s| s.name == stage.options[:before]})
              @stages.insert(index, old.delete(stage))
              old.delete(stage)
            end
          elsif stage.options[:after] && stage.options[:after] != :beginning
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

    @stages.compact!

    @sorted = true
  end

  def stop!;    @stopped = true;  end
  def restart!; @stopped = false; end

  def each (&block)
    self.sort!

    @stages.each {|stage|
      block.call stage

      break if @stopped
    }
  end

  def register (what, priority, callback, binding=nil)
    (@callbacks[what.to_sym] ||= []) << Callback.new(what, priority, callback, binding)

    @callbacks[what.to_sym].sort! {|a, b|
      if a.priority == b.priority
        a.position <=> b.position
      else
        a.priority <=> b.priority
      end
    }
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

  def owner= (value)
    @package = value

    @callbacks.each_value {|callbacks|
      callbacks.each {|callback|
        if callback.binding.is_a? Package
          callback.binding = @package
        end
      }
    }
  end
end

end