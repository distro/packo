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

module PackoBinary

class Package
  def self.envify (package)
    if !package
      return
    end

    ['binary', 'headers', 'documentation', 'debug', 'minimal', 'vanilla'].each {|flavor|
      if Packo::Environment['FLAVORS'].include?(flavor)
        package.flavors.send "#{flavor}!"
      else
        package.flavors.send "not_#{flavor}!"
      end
    }

    Packo::Environment['FEATURES'].split(/\s+/).each {|feature|
      feature = Packo::Feature.parse(feature)

      package.features {
        self.get(feature.name).merge(feature) if self.get(feature.name)
      }
    }

    package
  end

  attr_reader :categories, :name, :version, :slot, :tree

  def initialize (categories, name, version, slot=nil, tree=nil)
    @categories = (categories || '').split('/')
    @name       = name
    @version    = version
    @slot       = ((slot.empty? rescue nil) ? nil : slot)
    @tree       = tree
  end

  def == (package)
    self.name == package.name && self.categories == package.categories
  end

  def to_s (name=false)
    if name
      (@categories + [@name]).join('/')
    else
      "#{(@categories + [@name]).join('/')}#{"-#{@version}" if @version}#{"%#{@slot}" if @slot}"
    end
  end
end

end
