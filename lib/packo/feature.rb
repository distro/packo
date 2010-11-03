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

class Feature
  def self.parse (text)
    enabled = true

    if (tmp = text[0]) && (tmp == '-' || tmp == '+')
      text[0] = ''

      enabled = false if tmp == '-'
    end

    Feature.new(nil, text, enabled)
  end

  attr_reader :package, :name, :block

  def initialize (package, name, enabled=false, &block)
    @package = package
    @name    = name
    @enabled = enabled
    @block   = block

    if Packo::Features::Default[@name]
      self.instance_exec(self, &Packo::Features::Default[@name])
    end

    self.instance_exec(self, &@block) if @block
  end

  def enabled?;  !!@enabled       end
  def enabled!;  @enabled = true  end
  def disabled!; @enabled = false end

  def description (value=nil)
    value ? @description = value : @description
  end

  def on (what, priority=0, &block)
    @package.stages.register(what, priority, block, self)
  end

  def owner= (value)
    @package = value
  end
end

end
