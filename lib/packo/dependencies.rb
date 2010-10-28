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

require 'packo/dependency'

module Packo

class Dependencies
  attr_reader :package, :dependencies

  def initialize (package)
    @package = package

    @dependencies = []
  end

  def << (dependency)
    @dependencies.push(dependency.is_a?(Dependency) ? dependency : Dependency.parse(dependency))
    @dependencies.compact!
  end

  def each (&block)
    @dependencies.each {|dependency|
      block.call dependency
    }
  end

  def check
    package.stages.call :dependencies, package
  end
end

end