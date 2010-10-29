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
  attr_reader :package, :name, :block

  attr_accessor :description

  def initialize (package, name, &block)
    @package = package
    @name    = name
    @block   = block

    @enabled = false

    self.merge(Packo::Package::Features::Defaults[@name]) rescue nil

    self.instance_exec(self, &@block) if @block
  end

  def enabled?;  !!@enabled       end
  def enabled!;  @enabled = true  end
  def disabled!; @enabled = false end

  def on (what, priority=0, &block)
    @package.stages.register(what, priority, block, self)
  end

  def merge (feature)
    return if feature.nil?

    @enabled     = feature.enabled?
    @description = feature.description

    if !@block
      @block = feature.block
    end
  end

  def owner= (value)
    @package = value
  end
end

end
