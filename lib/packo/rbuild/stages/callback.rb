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

class Callback
  @@last = 0

  attr_accessor :binding

  attr_reader :name, :priority, :position

  def initialize (name, priority, callback, binding=nil)
    @name     = name
    @priority = priority
    @callback = callback
    @binding  = binding
    @position = @@last += 1
  end

  def call (*args)
    if binding
      binding.instance_exec(*args, &@callback)
    else
      @callback.call(*args)
    end
  end
end

end

end