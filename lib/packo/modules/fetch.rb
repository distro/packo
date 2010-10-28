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

require 'packo/module'

module Packo

module Modules

class Fetch < Module
  def initialize (package)
    super(package)

    Packo.env('DISTDIR', '/tmp') if !Packo.env('DISTDIR')

    package.stages.add :fetch,    self.method(:fetch),    :after => :dependencies
    package.stages.add :fetching, self.method(:fetching), :after => :fetch
    package.stages.add :fetched,  self.method(:fetched),  :after => :fetching
  end

  def fetch
    version = package.version

    package.source.each {|source|
      source = eval('"' + source + '"') rescue nil

      package.stages.call :fetch, source
    }
  end

  def fetching
    version = package.version

    distfiles = []

    package.source.each {|source|
      source = eval('"' + source + '"') rescue nil

      package.stages.call :fetching, source

      distfiles << "#{Packo.env('DISTDIR')}/#{File.basename(source)}"

      Packo.sh 'wget', '-c', '-O', distfiles.last, source
    }

    package.distfiles *distfiles
  end

  def fetched
    version = package.version

    package.source.each {|source|
      source = eval('"' + source + '"') rescue nil

      package.stages.call :fetched, source
    }
  end
end

end

end
