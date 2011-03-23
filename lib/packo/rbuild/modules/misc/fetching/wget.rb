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

module Packo; module RBuild; module Modules; module Fetching

class Wget < Module
  def self.fetch (path, to, package={})
    Packo.sh 'wget', '-c', '-O', to, path
  end

  def self.url (url, package={})
    Packo.interpolate(url, package)
  end

  def initialize (package)
    super(package)

    package.stages.add :fetch, self.method(:fetch), :after => :beginning
  end

  def fetch
    version = package.version

    distfiles = []
    sources   = [package.source].flatten.compact.map {|s|
      Wget.url(s, package)
    }

    package.stages.callbacks(:fetch).do(sources) {
      sources.each {|source|
        distfiles << "#{package.fetchdir || '/tmp'}/#{File.basename(source)}"

        Wget.fetch source, distfiles.last, package
      }
    }

    package.distfiles distfiles
  end
end

end; end; end; end
