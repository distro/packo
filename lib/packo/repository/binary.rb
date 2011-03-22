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

require 'nokogiri'

require 'packo/package'

module Packo; class Repository

class Binary < Repository
  class Package < Packo::Package
    class Build
      attr_reader :flavor, :features, :digest

      def initialize (data)
        @flavor   = data[:flavor]
        @features = data[:features]
        @digest   = data[:digest]
      end
    end

    attr_reader :builds

    def initialize (data)
      super(data)

      @builds = data[:builds] || []
    end
  end

  def self.parse (data)
    dom = Nokogiri::XML.parse(data)

    repo = Binary.new(type: dom.root['type'].to_sym, name: dom.root['name'])
    repo.generate(data)
    repo
  end

  def initialize (data)
    if data[:type] != :binary
      raise ArgumentError.new('It has to be a binary repository')
    end

    super(data)
  end

  def mirrors (data=nil)
    Nokogiri::XML.parse(data || File.read(self.path)).xpath('//mirrors/mirror').map {|e|
      e.text
    }
  end

  def packages (data=nil)
    Enumerator.new(self, :each_package, data)
  end

  def each_package (data=nil)
    Nokogiri::XML.parse(data || File.read(self.path)).xpath('//packages/package').each {|e|
      CLI.info "Parsing #{Packo::Package.new(tags: e['tags'].split(/\s+/), name: e['name'])}" if System.env[:VERBOSE]

      packages = []

      e.xpath('.//build').each {|build|
        package = Package.new(
          tags:     e['tags'],
          name:     e['name'],
          version:  build.parent['name'],
          slot:     (build.parent.parent.name == 'slot') ? build.parent.parent['name'] : nil,
          revision: build.parent['revision'],

          features: build.parent['features'],

          description: e.xpath('.//description').first.text,
          homepage:    e.xpath('.//homepage').first.text,
          license:     e.xpath('.//license').first.text,

          maintainer: e['maintainer']
        )

        if packages.member?(package)
          package = packages.find {|p| p == package}
        else
          packages << package
        end

        package.builds << Package::Build.new(
          flavor:   (build.xpath('.//flavor').first.text rescue ''),
          features: (build.xpath('.//features').first.text rescue ''),
          digest:   build['digest']
        )
      }

      packages.each {|package|
        yield package
      }
    }
  end
end

end; end
