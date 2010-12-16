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

require 'packo'
require 'thor'

module Packo; module CLI

def search_installed (expression, name=nil, type=nil)
  Models::InstalledPackage.search(expression, true, type && name ? "#{type}/#{name}" : nil).map {|pkg|
    Package.wrap(pkg)
  }
end

def search (expression, name=nil, type=nil, exact=false)
  packages = []

  if name && !name.empty?
    repository      = Package::Repository.parse(name)
    repository.type = type if Package::Repository::Types.member?(type.to_sym)
    repository      = Models::Repository.first(repository.to_hash)

    if repository
      packages << repository.search(expression, exact)
    end
  else
    Package::Repository::Types.each {|t|
      if type.nil? || type == 'all' || type == t
        Repository.all(:type => t).each {|repository|
          packages << repository.search(expression, exact)
        }
      end
    }
  end

  return packages.flatten.compact.map {|package|
    Package.wrap(package)
  }
rescue RuntimeError => e
  fatal e.message; exit 99
end

end; end
