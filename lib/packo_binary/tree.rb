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

class Tree
  def self.all (db)
    db.execute('SELECT * FROM trees').map {|tree|
      Tree.new(db, tree['name'])
    }
  end

  def self.name (dom)
    dom.elements.each('/tree/name') {|e| e.name == 'name'}.first.text rescue nil
  end

  def self.create (db, dom, path)
    name = Tree.name(dom)

    db.execute('INSERT OR IGNORE INTO trees VALUES(NULL, ?, ?)', [name, path])

    Tree.new(db, name)
  end

  attr_reader :id, :path

  def initialize (db, name)
    @db   = db
    @name = name

    result = @db.execute('SELECT * FROM trees WHERE name = ?', name).first

    @id   = result['id']
    @path = result['path']
  end

  def update
    _populate([@path])

    @db.commit rescue nil    
  end

  def search (package, exact=false)
    package = Packo::Package.parse(package)

    if !exact
      @db.execute(%{
        SELECT *

        FROM packages

        WHERE
          tree = ?
          #{'AND name LIKE ?' if package.name}
          #{'AND version LIKE ?' if package.version}
          #{'AND categories LIKE ?' if !package.categories.empty?}
      }, [@id,
        (package.name ? "%#{package.name}%" : nil),
        (package.version ? "%#{package.version}%" : nil),
        (!package.categories.empty? ? "%#{package.categories.join('/')}%" : nil)
      ].compact)
    else
      @db.execute(%{
        SELECT *

        FROM packages

        WHERE
          tree = ?
          #{'AND name = ?' if package.name}
          #{'AND version = ?' if package.version}
          #{'AND categories = ?' if !package.categories.empty?}
      }, [@id, package.name, package.version, package.categories.join('/')].compact)
    end
  end

  private

  def _populate (what)
    what.select {|what| File.directory? what}.each {|what|
      if File.file? "#{what}/#{File.basename(what)}.rbuild"
        Dir.glob("#{what}/#{File.basename(what)}-*.{rbuild,xml}").each {|version|
          version = version.match(/-(\d.*?)\.(rbuild|xml)$/)[1]

          @db.execute('INSERT OR IGNORE INTO packages VALUES(?, ?, ?, ?)', [
            File.basename(what), version, File.dirname(what.sub(%r{#{Regexp.escape(@path)}/}, '')), @id
          ])
        }
      else
        _populate(Dir.entries(what).map {|e| if e != '.' && e != '..' then "#{what}/#{e}" end}.compact)
      end
    }
  end
end
