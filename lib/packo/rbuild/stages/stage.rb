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

module Packo

class Stages

class Stage
  attr_reader :name, :options

  def initialize (name, method, options)
    @name    = name.to_sym
    @method  = method
    @options = options

    if (@options[:at] || @options[:after] == :beginning || @options[:before] == :ending) && @options[:strict].nil?
      @options[:strict] = true
    end
  end

  def call (*args)
    @method.call(*args)
  end

  def inspect
    "#<Stage: #{name} (#{@options.inspect})>"
  end
end

end

end
