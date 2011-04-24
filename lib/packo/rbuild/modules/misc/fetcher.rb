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

  def url (text)
    text.interpolate(package)
  end

  def filename (text)
    Fetcher.filename(url(text))
  end

  def fetch
    if package.source.is_a?(Hash)
      package.distfiles = {}

      sources = Hash[package.source.map {|(name, source)|
        next if package.digests[url(source)] && (Do.digest("#{package.fetchdir}/#{package.digests[url(source)].name}") rescue false) == package.digests[url(source)].digest

        url = Fetcher.url(source, package) or fail "Failed to get the real URL for: #{source}"

        [name, (
          if url.is_a?(Array) && url.length == 2
            url + [source]
          else
            ([url] + [nil, source]).flatten
          end
        )]
      }.compact]

      package.stages.callbacks(:fetch).do(sources) {
        sources.each {|name, (source, output, original)|
          package.distfiles[name] = OpenStruct.new(
            path: "#{package.fetchdir}/#{output || filename(source)}",
            url:  url(original)
          )

          package.fetch source, package.distfiles[name].path
        }

        package.source.each {|name, source|
          next if package.distfiles[name]

          package.distfiles[name] = OpenStruct.new(
            path: "#{package.fetchdir}/#{package.digests[url(source)].name}",
            url:  url(source)
          )
        }
      }
    else
      package.distfiles = []

      sources = [package.source].flatten.compact.map {|source|
        next if package.digests[url(source)] && (Do.digest("#{package.fetchdir}/#{package.digests[url(source)].name}") rescue false) == package.digests[url(source)].digest

        url = Fetcher.url(source, package) or fail "Failed to get the real URL for: #{source}"

        if url.is_a?(Array) && url.length == 2
          url + [source]
        else
          ([url] + [nil, source]).flatten
        end
      }.compact

      package.stages.callbacks(:fetch).do(sources) {
        sources.each {|(source, output, original)|
          package.distfiles << OpenStruct.new(
            path: "#{package.fetchdir}/#{output || filename(source)}",
            url:  url(original)
          )

          package.fetch source, package.distfiles.last.path
        }

        [package.source].flatten.compact.select {|source|
          !!package.digests[url(source)]
        }.each {|source|
          package.distfiles << OpenStruct.new(
            path: "#{package.fetchdir}/#{package.digests[url(source)].name}",
            url:  url(source)
          )
        }
      }
    end
  end

  def digest
    package.stages.callbacks(:digest).do(package.distfiles) {
      package.distfiles.each {|name, file|
        file ||= name

        original = package.digests[file.url].digest or next
        digest   = Do.digest(file.path) or next

        if digest != original
          raise ArgumentError.new("#{File.basename(file.path)} digest is #{digest} but should be #{original}")
        end
      }
    }
  end
end

end; end; end; end
