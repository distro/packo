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

    package.stages.add :fetch, self.method(:fetch), :after => :dependencies
  end

  def fetch
    version = package.version

    distfiles = []

    [package.source].flatten.each {|source|
      source = eval('"' + source + '"') rescue nil

      if (error = package.stages.call(:fetch, source).find {|result| result.is_a? Exception})
        Packo.debug error
        return
      end

      distfiles << "#{package.fetchdir || '/tmp'}/#{File.basename(source)}"

      if Packo.sh 'wget', '-c', '-O', distfiles.last, source
        if (error = package.stages.call(:fetched, source, distfiles.last).find {|result| result.is_a? Exception})
          Packo.debug error
          return
        end
      end
    }

    package.distfiles distfiles
  end
end

end

end
