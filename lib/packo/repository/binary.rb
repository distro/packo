#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free :software => you can redistribute it and/or modify
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
    data = YAML.parse(data).transform

    repo = Binary.new(:type => :binary, :name => data['name'])
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
    YAML.parse(data || File.read(self.path))['mirrors'].transform
  end

  def each_package (data=nil)
    YAML.parse(data || File.read(self.path)).transform['packages'].each {|name, data|
      package = Packo::Package.parse(name)

      CLI.info "Parsing #{package}" if System.env[:VERBOSE]

      packages = []

      data['builds'].each {|build|
        pkg = Package.new(
          :tags =>     package['tags'],
          :name =>     package['name'],
          :version =>  build['version'],
          :slot =>     build['slot'],
          :revision => build['revision'],

          :features => build['features'],

          :description => data['description'],
          :homepage =>    data['homepage'],
          :license =>     data['license'],

          :maintainer => data['maintainer']
        )

        if packages.member?(package)
          pkg = packages.find {|p| p == pkg}
        else
          packages << pkg
        end

        pkg.builds << Package::Build.new(
          :flavor =>   (build['flavor']   || ''),
          :features => (build['features'] || ''),
          :digest =>   build['digest']
        )
      }

      packages.each {|package|
        yield package
      }
    }
  end
end

end; end
