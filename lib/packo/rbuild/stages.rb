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

require 'packo/rbuild/stages/stage'
require 'packo/rbuild/stages/callbacks'

module Packo; module RBuild

class Stages
  module Callable
    def before (name, data=nil, &block)
      self.package.stages.register(:before, name, block, { :binding => self }.merge(data || {}))
    end

    def after (name, data=nil, &block)
      self.package.stages.register(:after, name, block, { :binding => self }.merge(data || {}))
    end

    def avoid (chain, name, known=nil)
      self.package.stages.unregister(chain, name, known)
    end
  end

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

  def delete (name, method=nil)
    @stages.delete_if {|stage|
      stage.name == name && (!method || stage.method == method)
    }

    @sorted = false
  end

  # Ugly incomprensibile shit ahead. It's dangerous to go alone! Take this! <BS>
  #
  # In short it tries to sort stuff as it wanted to be placed depending on stage's options
  def sort! (strict=false)
    return if @sorted

    functions = [lambda {|stages|
      stages.each {|stage|
        next if (!stage.options[:before] && !stage.options[:after]) || stage.options[:before] == :end || stage.options[:after] == :beginning

        @stages.delete(stage)

        index = nil

        if stage.options[:before]
          index = @stages.find_index {|s|
            s.name == stage.options[:before]
          }
        end
        
        if stage.options[:after]
          index = @stages.find_index {|s|
            s.name == stage.options[:after]
          }
        end

        @stages.insert(index + 1, stage) if index
      }
    },

    lambda {|stages|
      stages.each {|stage|
        next if !stage.options[:at]

        @stages.delete(stage)

        if stage.options[:at] == :beginning
          @stages.unshift stage
        elsif stage.options[:at] == :end
          @stages.push stage
        end
      }
    },

    lambda {|stages|
      stages.each {|stage|
        next if stage.options[:before] != :end && stage.options[:after] != :beginning

        @stages.delete(stage)

        if stage.options[:after] == :beginning
          index = @stages.reverse.find_index {|s|
            s.options[:at] == :beginning
          } || @stages.length

          @stages.insert(@stages.length - index, stage)
        elsif stage.options[:before] == :end
          index = @stages.find_index {|s|
            s.options[:at] == :end
          } || 0

          @stages.insert(index - 1, stage)
        end
      }
    }]

    functions.reverse! unless strict

    functions.each {|function|
      if strict
        stages = @stages.select {|stage|
          stage.options[:strict]
        }
      else
        stages = @stages.dup
      end

      stages = stages.group_by {|stage|
        stage.options[:priority]
      }

      stages.keys.sort.reverse_each {|key|
        function.call(stages[key])
      }
    }

    self.sort!(true) if !strict

    @sorted = true
  end

  def stop!;    @stopped = true;  end
  def restart!; @stopped = false; end

  def each (&block)

    ap @stages
    self.sort!
    ap @stages

    @stages.each {|stage|
      block.call stage

      break if @stopped
    }
  end

  def register (chain, name, callback, data={})
    (@callbacks[name.to_sym] ||= Callbacks.new(name.to_sym)).register(chain, callback, data)
  end

  def unregister (chain, name, known=nil)
    (@callbacks[name.to_sym] ||= Callbacks.new(name.to_sym)).unregister(chain, known)
  end

  def callbacks (name)
    @callbacks[name.to_sym] ||= Callbacks.new(name.to_sym)
  end
end

end; end
