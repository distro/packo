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

require 'net/http'
require 'uri'

module Packo

module Modules

module Fetching

class SourceForge < Module
  def initialize (package)
    super(package)

    package.stages.add :fetch, self.method(:fetch), :after => :beginning
  end

  def fetch
    matches = Packo.interpolate(package.source, self).match(%r{^(.*?)/(.*?)$})

    name    = matches[1]
    version = matches[2]

    body   = Net::HTTP.get(URI.parse("http://sourceforge.net/projects/#{name}/files/#{name}/#{version}/#{name}-#{version}.tar.bz2/download"))
    source = URI.decode(body.match(%r{href="(http://downloads.sourceforge.net.*?)"})[1])

    if (error = package.stages.call(:fetch, source).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end

    package.distfiles ["#{package.fetchdir || '/tmp'}/#{File.basename(source).sub(/\?.*$/, '')}"]

    Packo.sh 'wget', '-c', '-O', package.distfiles.last, source

    if (error = package.stages.call(:fetched, source, package.distfiles.last).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end
  end
end

end

end

end
