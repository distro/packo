#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

module Packo; module RBuild

class Stages
  class Stage
    attr_reader :name, :options, :method

    def initialize (name, method, options)
      @name    = name.to_sym
      @method  = method
      @options = options

      if (@options[:at] || @options[:after] == :beginning || @options[:before] == :ending) && @options[:strict].nil?
        @options[:strict] = true
      end

      @options[:priority] ||= 0
    end

    def call (*args)
      @method.call(*args)
    end

    def == (value)
      @name == value || @method == value
    end

    def inspect
      "#<Stage: #{name} (#{@options.inspect})>"
    end
  end

  attr_reader :package, :stages

  def initialize (package)
    @package = package

    @stages    = []
  end

  def owner_of (name)
    name = name.to_sym

    @stages.find {|stage|
      stage.name == name
    }.method.owner rescue nil
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

    funcs = {
      atom: lambda {
        { stricts: [], normals: [] }
      },

      leaf: lambda {
        Hash[
          after:  funcs[:atom].call,
          before: funcs[:atom].call,
          at:     funcs[:atom].call,
          stage:  nil
        ]
      },

      type: lambda {|stage|
        stage.options[:strict] ? :stricts : :normals
      },

      plain: lambda {|pi|
        pi.sort {|a, b|
          pr = (a[:stage].options[:priority] || 0) <=> (b[:stage].options[:priority] || 0)
          pr.zero? ? a[:stage].name.to_s.downcase <=> b[:stage].name.to_s.downcase : pr
        }.map {|l|
          funcs[:flat].call(l)
        }.flatten
      },

      flat: lambda {|leaf|
        funcs[:plain].call(leaf[:after][:normals]) + funcs[:plain].call(leaf[:after][:stricts]) +
          (leaf[:stage] ? [leaf[:stage]] : (funcs[:plain].call(leaf[:at][:stricts]) + funcs[:plain].call(leaf[:at][:normals]))) +
          funcs[:plain].call(leaf[:before][:stricts]) + funcs[:plain].call(leaf[:before][:normals])
      }
    }

    tree = { beginning: funcs[:leaf].call, end: funcs[:leaf].call }

    remained = @stages.dup
    prev_rem = @stages.size

    begin
      prev_rem = remained.size

      remained.dup.each {|stage|
        place = (if tree[stage.options[:after]]
          [stage.options[:after], :before, funcs[:type].call(stage)]
        elsif tree[stage.options[:before]]
          [stage.options[:before], :after, funcs[:type].call(stage)]
        elsif [:beginning, :end].include?(stage.options[:at])
          [stage.options[:at], :at, funcs[:type].call(stage)]
        else
          nil
        end)

        next unless place

        remained.delete(stage)

        leaf         = funcs[:leaf].call
        leaf[:stage] = stage

        tree[place[0]][place[1]][place[2]] << leaf

        tree[stage.name.to_sym] = leaf
      }
    end while prev_rem != remained.size

    tree[:beginning][:after] = tree[:end][:before] = funcs[:atom].call

    @stages = funcs[:flat].call(tree[:beginning]) + funcs[:flat].call(tree[:end])
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

end

end; end
