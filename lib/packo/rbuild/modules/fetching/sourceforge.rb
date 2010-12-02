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

module Packo; module RBuild; module Modules; module Fetching

class SourceForge < Module
  def self.fetch (url, to, package={})
    if !url.include?('downloads.sourceforge.net')
      url = SourceForge.url(url, package)
    end

    Packo.sh 'wget', '-c', '-O', to, url
  end

  def self.url (url, package={})
    matches = Packo.interpolate(url, package).match(%r{^(.*?)/(.*?)$})

    project = matches[1]
    path    = matches[2]

    body = Net::HTTP.get(URI.parse("http://sourceforge.net/projects/#{project}/files/#{File.dirname(path)}/"))
    body = Net::HTTP.get(URI.parse(body.scan(%r{href="(.*?#{project}/files/#{path}\..*?/download)"}).find {|(url)|
      url.match(%r{((tar\.(lzma|xz|bz2|gz))|zip|rar)/download$})
    }.first))

    URI.decode(body.match(%r{href="(http://downloads.sourceforge.net.*?)"})[1])
  end

  def initialize (package)
    super(package)

    package.stages.add :fetch, self.method(:fetch), :after => :beginning
  end

  def fetch
    source = SourceForge.url(package.source, package)

    package.stages.callbacks(:fetch).do {
      package.distfiles ["#{package.fetchdir || '/tmp'}/#{File.basename(source).sub(/\?.*$/, '')}"]

      SourceForge.fetch source, package.distfiles.last
    }
  end
end

end; end; end; end
