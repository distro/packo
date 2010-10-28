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

class Dependency
  attr_reader :name, :categories, :version, :flavors

  def self.parse (text)
    parsed = Packo::Package.parse(text)

    Dependency.new(parsed.name, parsed.categories, parsed.version, parsed.flavors)
  end

  def initialize (name, categories, version, flavors)
    @name       = name
    @categories = categories
    @version    = version
    @flavors    = flavors
  end

  def to_s
    "#{(@categories + [@name]).join('/')}#{"-#{@version}" if @version}[#{@flavors.inspect}]"
  end
end

end
