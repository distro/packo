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

module Fetching

class Wget < Module
  def initialize (package)
    super(package)

    package.stages.add :fetch, self.method(:fetch), :after => :beginning

    package.on :initialize do |package|
      package.fetch = Class.new(Module::Helper) {
        def url (source=nil)
          if source.is_a? Integer
            Packo.interpolate(package.source[source], package)
          elsif source.is_a? String
            Packo.interpolate(source, package)
          else
            Packo.interpolate(package.source.first, package)
          end
        end
      }.new(package)
    end
  end

  def fetch
    version = package.version

    distfiles = []

    [package.source].flatten.compact.each {|source|
      source = package.fetch.url(source)

      if (error = package.stages.call(:fetch, source).find {|result| result.is_a? Exception})
        Packo.debug error
        next
      end

      distfiles << "#{package.fetchdir || '/tmp'}/#{File.basename(source)}"

      Packo.sh 'wget', '-c', '-O', distfiles.last, source

      if (error = package.stages.call(:fetched, source, distfiles.last).find {|result| result.is_a? Exception})
        Packo.debug error
        next
      end
    }

    package.distfiles distfiles
  end
end

end

end

end