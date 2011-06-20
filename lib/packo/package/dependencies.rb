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

require 'packo/package/dependency'

module Packo; class Package

class Dependencies < Array
  Types = [:runtime, :build, :build_and_runtime,
           :recommends, :suggests,
           :breaks, :conflicts,
           :enhances, :replaces, :provides]

  attr_reader :package

  def initialize (package)
    if package.is_a?(Array)
      package.each {|dep|
        push dep
      }
    else
      @package = package
    end
  end

  def push (dependency)
    super(Dependency.parse(dependency))

    self.compact!
    self.uniq!
    self
  end

  alias << push

  def set (&block)
    self.instance_eval &block
  end

  def depends (text)
    push Dependency.parse(text)
  end; alias depends_on depends

  Types.each {|name|
    define_method name do |text=nil|
      if text
        push Dependency.parse(text, name)
      else
        select {|dep|
          dep.type == name
        }
      end
    end
  }
end

end; end
