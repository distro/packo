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

require 'packo/rbuild/dependency'

module Packo; module RBuild

class Dependencies < Array
  attr_reader :package

  def initialize (package)
    @package = package
  end

  alias __push push

  def push (dependency)
    __push(dependency.is_a?(Dependency) ? dependency : Dependency.parse(dependency))
    self.compact!
    self
  end

  alias << push

  def check
    package.stages.call :dependencies, package
    package.stages.call :dependencies!, package
  end

  def owner= (value)
    @package = value
  end
end

end; end
