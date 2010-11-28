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

require 'packo/models'

module Packo; module Binary; class Repository

class Binary < Repository
  def initialize (repository)
    super(repository)

    dom = Nokogiri::XML.parse(File.read(self.path))

    dom.xpath('//mirrors/mirror').each {|e|
      repository.data.mirrors.first_or_create(:uri => e.text)
    }
  end

  def populate
    dom = Nokogiri::XML.parse(File.read(self.path))

    dom.xpath('//packages/package').each {|e|
      e.xpath('.//build').each {|build|
        package = Packo::Package.new(
          :tags     => e['tags'].split(/\s+/),
          :name     => e['name'],
          :version  => build.parent['name'],
          :slot     => (build.parent.parent.name == 'slot') ? build.parent.parent['name'] : nil,
          :revision => build.parent['revision'],
        )

        pkg = repository.packages.first_or_create(
          :repo => repository,

          :tags_hashed => package.tags.hashed,
          :name        => package.name,
          :version     => package.version,
          :slot        => package.slot,
          :revision    => package.revision
        )

        pkg.update(
          :description => e['description'],
          :homepage    => e['homepage'],
          :license     => e['license']
        )

        package.tags.each {|tag|
          pkg.tags.first_or_create(:name => tag.to_s)
        }

        pkg.data.update(
          :features => build.parent['features']
        )

        bld = pkg.data.builds.first_or_create(
          :flavor   => (build.xpath('.//flavor').first.text rescue ''),
          :features => (build.xpath('.//features').first.text rescue ''),
        )

        bld.update(
          :digest => build['digest']
        )
      }
    }
  end
end

end; end; end
