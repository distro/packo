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
require 'digest/sha1'

module Packo; module RBuild; module Modules; module Misc

class Fetcher < Module
  @@wrappers = {}

  def self.register (name, &block)
    @@wrappers[name.to_sym] = block
  end

  def self.url (url, package)
    whole, scheme, url = url.to_s.match(%r{^(.+?)://(.+)$}).to_a

    raise ArgumentError.new('Invalid URI passed') unless whole

    if ['https', 'http', 'ftp'].member?(scheme)
      "#{scheme}://#{url.interpolate(package)}"
    elsif @@wrappers[scheme.to_sym]
      @@wrappers[scheme.to_sym].call(url, package)
    else
      raise ArgumentError.new('Scheme not supported')
    end
  end

  def self.fetch (url, to)
    if !System.env[:FETCHER]
      raise RuntimeError.new('Set a FETCHER variable.')
    end

    Packo.sh System.env[:FETCHER].interpolate(OpenStruct.new(
      source: Fetcher.url(url, self),
      output: to
    )).gsub('%o', to).gsub('%u', Fetcher.url(url, self)), silent: !System.env[:VERBOSE]
  end

  def self.filename (text)
    return unless text

    File.basename(text).sub(/\?.*$/, '')
  end

  def initialize (package)
    super(package)

    package.stages.add :fetch,  self.method(:fetch),  after: :beginning
    package.stages.add :digest, self.method(:digest), after: :fetch, strict: true

    after :initialize do |result, package|
      package.define_singleton_method :fetch, &Fetcher.method(:fetch)
    end
  end

  def finalize
    package.stages.delete :fetch,  self.method(:fetch)
    package.stages.delete :digest, self.method(:digest)
  end

  def fetch
    if package.source.is_a?(Hash)
      distfiles = {}
      sources   = Hash[package.source.dup.map {|(name, source)|
        next if (Do.digest("#{package.fetchdir}/#{Fetcher.filename(source.interpolate(package))}") rescue false) == package.digests[Fetcher.filename(source.interpolate(package))]

        [name, (Fetcher.url(source, package) or fail "Failed to get the real URL for: #{source}")]
      }.compact]

      package.stages.callbacks(:fetch).do(sources) {
        sources.each {|name, source|
          distfiles[name] = "#{package.fetchdir}/#{Fetcher.filename(source)}"

          package.fetch source, distfiles[name]
        }

        package.source.each {|name, source|
          next if distfiles[name]

          distfiles[name] = "#{package.fetchdir}/#{Fetcher.filename(source.interpolate(package))}"
        }
      }
    else
      distfiles = []
      sources   = [package.source].flatten.compact.map {|source|
        next if (Do.digest("#{package.fetchdir}/#{Fetcher.filename(source.interpolate(package))}") rescue false) == package.digests[Fetcher.filename(source.interpolate(package))]

        Fetcher.url(source, package) or fail "Failed to get the real URL for: #{source}"
      }.compact

      package.stages.callbacks(:fetch).do(sources) {
        sources.each {|(source, output)|
          distfiles << "#{package.fetchdir}/#{output || Fetcher.filename(source)}"

          package.fetch source, distfiles.last
        }

        [package.source].flatten.compact.each {|source|
          next if distfiles.member?("#{package.fetchdir}/#{Fetcher.filename(source.interpolate(package))}")

          distfiles << "#{package.fetchdir}/#{Fetcher.filename(source.interpolate(package))}"
        }
      }
    end

    package.distfiles = distfiles
  end

  def digest
    package.stages.callbacks(:digest).do(package.distfiles) {
      if package.distfiles.is_a?(Hash)
        distfiles = package.distfiles.values
      else
        distfiles = package.distfiles
      end

      distfiles.each {|file|
        original = package.digests[Fetcher.filename(file)] or next
        digest   = Do.digest(file) or next

        if digest != original
          raise ArgumentError.new("#{File.basename(file)} digest is #{digest} but should be #{original}")
        end
      }
    }
  end
end

end; end; end; end
