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

module Packo; class Package

class Feature
  def self.parse (text)
    Feature.new(text.match(/^[\+\-]?(.*)$/)[1], !text.start_with?('-'))
  end

  attr_reader :name

  def initialize (name, enabled=false, description=nil)
    @name        = name.to_sym
    @enabled     = !!enabled
    @description = description
  end

  def enabled?;  @enabled         end
  def disabled?; !@enabled        end
  def enabled!;  @enabled = true  end
  def disabled!; @enabled = false end

  def description (value=nil)
    value ? @description = value : @description
  end
end

end; end
