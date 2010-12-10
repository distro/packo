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

require 'uri'

module Packo; module RBuild; module Modules; module Misc

class Fetcher < Module
  @@wrappers = {}

  def self.register (name, &block)
    @@wrappers[name.to_sym] = block
  end

  def self.url (url, package)
    matches = url.to_s.match(%r{^(.+?)://(.+)$})

    raise ArgumentError.new('Invalid URI passed') unless matches

    scheme = matches[1]
    url    = matches[2]

    if ['https', 'http', 'ftp'].member?(scheme)
      "#{scheme}://#{url.interpolate(package)}"
    elsif @@wrappers[scheme.to_sym]
      @@wrappers[scheme.to_sym].call(url, package)
    else
      raise ArgumentError.new('Scheme not supported')
    end
  end

  def initialize (package)
    super(package)

    package.stages.add :fetch, self.method(:fetch), :after => :beginning

    after :initialize do |result, package|
      package.define_singleton_method :fetch do |url, to|
        if !System.env[:FETCHER]
          raise RuntimeError.new('Set a FETCHER variable.')
        end

        Packo.sh System.env[:FETCHER].interpolate(OpenStruct.new(
          :source => Fetcher.url(url, self),
          :output => to
        )).gsub('%o', to).gsub('%u', Fetcher.url(url, self)), :silent => !System.env[:VERBOSE]
      end
    end
  end

  def fetch
    version = package.version

    distfiles = []
    sources   = [package.source].flatten.compact.map {|s|
      Fetcher.url(s, package)
    }

    package.stages.callbacks(:fetch).do(sources) {
      sources.each {|source|
        distfiles << "#{package.fetchdir || '/tmp'}/#{File.basename(source)}"

        package.fetch source, distfiles.last
      }
    }

    package.distfiles distfiles
  end
end

end; end; end; end
