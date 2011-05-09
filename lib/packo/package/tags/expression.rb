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

require 'packo/package/tags/expression/name'
require 'packo/package/tags/expression/logic'
require 'packo/package/tags/expression/group'

require 'stringio'

module Packo; class Package; class Tags < Array



class Expression
  class EvaluationError < Exception
  end

  def self.parse (text)
    base  = Group.new
    name  = nil
    stack = [base]
    logic = nil

    text.to_s.each_char.to_a.each_with_index {|char, index|
      begin
        if char == ')' && stack.length == 1
          raise SyntaxError.new('Closing an unopened parenthesis')
        end

        if char.match(/\s|\(|\)/) || (!logic && ['|', '&', '!'].member?(char))
          if logic || (name && name.match(/(and|or|not)/i))
            stack.last << Logic.new(logic || name)
            logic       = nil
            name        = nil
          elsif name
            stack.last << Name.new(name)
            name        = nil
          end
        end

        if name || logic
          name  << char if name
          logic << char if logic
        else
          case char
            when '('; stack.push Group.new
            when ')'; stack[-2] << stack.pop
            when '|'; logic = '|'
            when '&'; logic = '&'
            when '!'; stack.last << Logic.new('!')
            else;     name = char if !char.match(/\s/)
          end
        end
      rescue SyntaxError => e
        raise "#{e.message} near `#{text[index - 4, 8]}` at character #{index}"
      end
    }

    if stack.length != 1
      raise SyntaxError.new('Not all parenthesis are closed')
    end

    if logic
      raise SyntaxError.new('The expression cannot end with a logic operator')
    end

    base << Name.new(name) if name

    Expression.new(base)
  end

  attr_reader :base

  def initialize (base=Group.new)
    @base = base
  end

  def evaluate (package)
    _evaluate(@base, package.is_a?(Array) ? package : package.tags.to_a)
  end

  def to_s
    @base.inspect
  end

  private
    def _evaluate (group, tags)
      values = []

      group.each {|thing|
        case thing
          when Logic; values << thing
          when Group; values << _evaluate(thing, tags)
          when Name;  values << tags.member?(thing)
        end
      }

      at = 0
      while at < values.length
        if values[at].is_a?(Logic) && values[at].type == :not
          values.delete_at(at)
          values[at] = !values[at]
        end

        at += 1
      end

      while values.length > 1
        if values.first.is_a?(Logic) && values.first.type == :not
          values.shift
          values.first = !values.first
        else
          a, logic, b = values.shift(3)
          values.unshift(logic.evaluate(a, b))
        end
      end

      return values.pop
    end
end

end; end; end
