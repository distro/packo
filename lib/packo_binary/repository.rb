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

require 'ostruct'

module PackoBinary

class Repository
  def self.parse (text)
    if text.include?('/')
      type, name = text.split('/')
    else
      type, name = nil, name
    end

    OpenStruct.new(
      :type => type,
      :name => name
    )
  end

  def self.all (db, type=nil)
    db.execute("SELECT * FROM repositories #{'WHERE type = ?' if type}", [type].compact).map {|repo|
      Repository.new(db, repo['name'], repo['type'])
    }
  end

  def self.find (db, name, type=nil)
    type, name = (tmp = Repository.parse(name); [tmp.type, tmp.name]) if !type

    repo = db.execute('SELECT name, type FROM repositories WHERE name = ? AND type = ?', [name, type]).first

    Repository.new(db, repo['name'], repo['type'])
  end

  def self.name (dom)
    dom.root.attributes['name']
  end

  def self.create (db, type, dom, uri, path)
    name = Repository.name(dom)

    db.execute('INSERT OR IGNORE INTO repositories VALUES(NULL, ?, ?, ?, ?)', [name, type.to_s, uri, path])

    repository = Repository.new(db, name, type)

    if type == :binary
      dom.elements.each('//mirrors/mirror') {|e|
        repository.add_mirror e.text
      }
    end

    repository
  end

	def self.delete (db, name, type)
		repo = db.execute('SELECT * FROM repositories WHERE name = ? AND type = ?', [name, type.to_s]).first

		db.execute('SELECT * FROM packages WHERE repository = ?', repo['id']).each {|package|
			case type
				when :binary; db.execute('DELETE FROM binary_builds WHERE package = ?', package['id'])
				when :source; db.execute('DELETE FROM source_features WHERE package = ?', package['id'])
			end
		}

		db.execute('DELETE FROM packages WHERE repository = ?', repo['id'])

    if type == :binary
      db.execute('DELETE FROM binary_mirrors WHERE repository = ?', repo['id'])
    end

		db.execute('DELETE FROM repositories WHERE id = ?', repo['id'])

		db.commit rescue nil
	end

  include Helpers

  attr_reader :id, :type, :name, :uri, :path

  def initialize (db, name, type)
    @db   = db
    @name = name
		@type = type.to_sym

    result = @db.execute('SELECT * FROM repositories WHERE name = ? AND type = ?', [name, type.to_s]).first

    @id   = result['id']
    @uri  = result['uri']
    @path = result['path']

    if @type == :binary
      define_singleton_method :mirrors do
        @db.execute('SELECT * FROM binary_mirrors WHERE repository = ?', @id).map {|mirror| mirror['uri']}
      end

      define_singleton_method :add_mirror do |uri|
        @db.execute('INSERT INTO binary_mirrors VALUES(?, ?)', [@id, uri])
      end
    end
  end

  def update
		case @type
			when :binary; _populate_binary(REXML::Document.new(File.new(@path)).elements.each('//packages') {}.first)
			when :source; _populate_source([@path], @path)
		end

		@db.commit rescue nil
  end

  def search (package, exact=false)
    package = Packo::Package.parse(package)

    if !exact
      @db.execute(%{
        SELECT *

        FROM packages

        WHERE
          repository = ?
          #{'AND categories LIKE ?' if !package.categories.empty?}
          #{'AND name LIKE ?' if package.name}
          #{'AND version LIKE ?' if package.version}
      }, [@id,
        (!package.categories.empty? ? "%#{package.categories.join('/')}%" : nil),
        (package.name ? "%#{package.name}%" : nil),
        (package.version ? "%#{package.version}%" : nil)
      ].compact)
    else
      @db.execute(%{
        SELECT *

        FROM packages

        WHERE
          repository = ?
          #{'AND categories = ?' if !package.categories.empty?}
          #{'AND name = ?' if package.name}
          #{'AND version = ?' if package.version}
      }, [@id,
        (package.categories.empty? ? nil : package.categories.join('/')),
        package.name,
        package.version
      ].compact)
    end
  end

  private

	def _populate_binary (dom, categories='')
		categories[0, 1] = '' if categories[0] == '/'

		dom.elements.each {|e|
			if e.name != 'package'
				_populate_binary(e, "#{categories}/#{e.name}")
			else
				name        = e.attributes['name']
				description = e.attributes['description']
				homepage    = e.attributes['homepage']
				license     = e.attributes['license']

				e.elements.each('.//build') {|build|
					version  = build.parent.attributes['name']
          digest   = build.attributes['digest']
					features = build.elements.each('.//features') {}.first.text rescue nil
					flavors  = build.elements.each('.//flavors') {}.first.text rescue nil
					slot     = build.parent.parent.name == 'slot' ? build.parent.parent.attributes['name'] : nil

					@db.execute('INSERT OR IGNORE INTO packages VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?)', [@id,
						categories, name, version.to_s, slot.to_s, description.to_s, homepage.to_s, license.to_s
					])

					id = @db.execute('SELECT * FROM packages WHERE repository = ? AND categories = ? AND name = ? AND version = ? AND slot = ?', [@id,
						categories, name, version.to_s, slot.to_s
					]).first['id']

					@db.execute('INSERT OR REPLACE INTO binary_builds VALUES(?, ?, ?, ?)', [id, features, flavors, digest])

          @db.execute('INSERT OR IGNORE INTO binary_features VALUES(?, ?)', [id, build.parent.attributes['features']])
				}
			end
		}
	end

  def _populate_source (what, root=nil)
    last = nil

    what.select {|what| File.directory? what}.each {|what|
      categories = File.dirname(what[(root || '').length + 1, what.length]) rescue nil

      if categories && categories != '.'
        next if categories[0] == '.'

        info "Parsing #{categories}" if categories != last && Packo::Environment[:VERBOSE]

        last = categories
      end

      if File.file? "#{what}/#{File.basename(what)}.rbuild"
        Dir.glob("#{what}/#{File.basename(what)}-*.{rbuild,xml}").each {|version|
          package = PackoBinary::Package.new(categories, File.basename(what), version.match(/-(\d.*?)\.(rbuild|xml)$/)[1])

          begin
            loadPackage(what, package)
          rescue LoadError => e
            warn e.to_s if Packo::Environment[:VERBOSE]
          end

          package = Packo::Packages[package.to_s]

          if !package
            warn "Package not found: #{File.basename(what)}" if Packo::Environment[:VERBOSE]
            next
          end

          @db.execute('INSERT OR REPLACE INTO packages VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?)', [@id,
            package.categories.join('/'), package.name, package.version.to_s, package.slot.to_s,
            package.description, [package.homepage].flatten.join(' '), [package.license].flatten.join(' ')
          ])

					id = @db.execute('SELECT * FROM packages WHERE repository = ? AND categories = ? AND name = ? AND version = ? AND slot = ?', [@id,
						package.categories.join('/'), package.name, package.version.to_s, package.slot.to_s,
					]).first['id']

          package.features.each {|feature|
            @db.execute('INSERT OR REPLACE INTO source_features VALUES(?, ?, ?, ?)', [id,
              feature.name, feature.description, (feature.enabled?) ? 1 : 0
            ])
          }

          Packo::Packages.delete package.to_s(true)
          Packo::Packages.delete package.to_s
        }
      else
        _populate_source(Dir.entries(what).map {|e|
					"#{what}/#{e}" if e != '.' && e != '..'
				}.compact, root)
      end
    }
  end
end

end
