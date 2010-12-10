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

module Packo; module RBuild; module Modules; module Misc

Fetcher.register :sourceforge, do |url, package|
  matches = url.interpolate(package).match(%r{^(.*?)/(.*?)$})

  project = matches[1]
  path    = matches[2]

  body = Net::HTTP.get(URI.parse("http://sourceforge.net/projects/#{project}/files/#{File.dirname(path)}/"))


  urls = body.scan(%r{href="(.*?#{project}/files/#{path}\..*?/download)"}).select {|(url)|
    url.match(%r{((tar\.(lzma|xz|bz2|gz))|zip|rar)/download$})
  }.map {|(url)| url}

  url = nil
  ['xz', 'lzma', 'bz2', 'gz', 'zip' 'rar'].each {|compression|
    url = urls.find {|url|
      url.match(%r{\.#{compression}/download$})
    }

    break if url
  }

  URI.decode(Net::HTTP.get(URI.parse(url)).match(%r{href="(http://downloads.sourceforge.net.*?)"})[1])
end

end; end; end; end
