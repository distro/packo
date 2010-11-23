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

module Packo; module Binary; class Repository

class Binary < Repository
  def initialize (name, uri, path)
    super(:binary, name, uri, path)
  end

  def populate (dom=Nokogiri::XML.parse(File.read(self.path)), categories='')
    categories[0, 1] = '' if categories[0] == '/'

    dom.elements.each {|e|
      if e.name != 'package'
        populate(e, "#{categories}/#{e.name}")
      else
        e.xpath('.//build').each {|build|
          package = repo.packages.create(
            :categories => categories,
            :name       => e['name'],
            :version    => build.parent['name'],
            :slot       => build.parent.parent['name'],
            :revision   => build.parent['revision'],

            :description => e['description'],
            :homepage    => e['homepage'],
            :license     => e['license']
          )

          package.data.builds.create(
            :flavor   => (build.elements.xpath('.//flavor').first.text rescue nil),
            :features => (build.elements.xpath('.//features').first.text rescue nil),

            :digest => build['digest']
          )

          package.data.features

          @db.execute('INSERT OR REPLACE INTO binary_builds VALUES(?, ?, ?, ?)', [id, features, flavors, digest])

          @db.execute('INSERT OR IGNORE INTO binary_features VALUES(?, ?)', [id, build.parent['features']])
        }
      end
    }
  end
end

end; end; end
