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

module Packo

module Binary

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
    if name.is_a? Integer
      repo = db.execute('SELECT name, type FROM repositories WHERE id = ?', name).first
    else
      type, name = (tmp = Repository.parse(name); [tmp.type, tmp.name]) if !type
      repo = db.execute('SELECT name, type FROM repositories WHERE name = ? AND type = ?', [name, type]).first
    end

    return if !repo

    Repository.new(db, repo['name'], repo['type'])
  end

  def self.name (dom)
    dom.root['name']
  end

  def self.create (db, type, dom, uri, path)
    name = Repository.name(dom)

    db.execute('INSERT OR IGNORE INTO repositories VALUES(NULL, ?, ?, ?, ?)', [name, type.to_s, uri, path])

    repository = Repository.new(db, name, type)

    if type == :binary
      dom.xpath('//mirrors/mirror').each {|e|
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
			when :binary; _populate_binary(Nokogiri::XML.parse(File.read(@path)).xpath('//packages').first)
			when :source; _populate_source([@path], @path)
		end

		@db.commit rescue nil
  end

  def search (expression, exact=false)
    if matches = expression.match(/^([<>]?=?)/)
      validity = ((matches[1] && !matches[1].empty?) ? matches[1] : nil)
      expression = expression.sub(/^([<>]?=?)/, '')

      validity = nil if validity == '='
    else
      validity = nil
    end

    package = Packo::Package.parse(expression)

    if !exact
      result = @db.execute(%{
        SELECT *

        FROM packages

        WHERE
          repository = ?
          #{'AND categories LIKE ?' if !package.categories.empty?}
          #{'AND name LIKE ?' if package.name}
          #{'AND version LIKE ?' if package.version && !validity}
      }, [@id,
        (!package.categories.empty? ? "%#{package.categories.join('/')}%" : nil),
        (package.name ? "%#{package.name}%" : nil),
        (package.version && !validity ? "%#{package.version}%" : nil)
      ].compact)
    else
      result = @db.execute(%{
        SELECT *

        FROM packages

        WHERE
          repository = ?
          #{'AND categories = ?' if !package.categories.empty?}
          #{'AND name = ?' if package.name}
          #{'AND version = ?' if package.version && !validity}
      }, [@id,
        (package.categories.empty? ? nil : package.categories.join('/')),
        package.name,
        package.version && !validity ? package.version : nil 
      ].compact)
    end

    return result if !validity

    result.select {|pkg|
      case validity
        when '>';  Versionomy.parse(pkg['version']) >  package.version
        when '>='; Versionomy.parse(pkg['version']) >= package.version
        when '<';  Versionomy.parse(pkg['version']) <  package.version
        when '<='; Versionomy.parse(pkg['version']) <= package.version
      end
    }
  end

  private

	def _populate_binary (dom, categories='')
		categories[0, 1] = '' if categories[0] == '/'

		dom.elements.each {|e|
			if e.name != 'package'
				_populate_binary(e, "#{categories}/#{e.name}")
			else
				name        = e['name']
				description = e['description']
				homepage    = e['homepage']
				license     = e['license']

				e.elements.each('.//build') {|build|
					version  = build.parent['name']
          digest   = build['digest']
					features = build.elements.xpath('.//features').first.text rescue nil
					flavors  = build.elements.xpath('.//flavors').first.text rescue nil
					slot     = build.parent.parent.name == 'slot' ? build.parent.parent['name'] : nil
          revision = build.parent['revision']

					@db.execute('INSERT OR REPLACE INTO packages VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [@id,
						categories, name, version.to_s, slot.to_s, revision.to_i, description.to_s, homepage.to_s, license.to_s
					])

					id = @db.execute('SELECT * FROM packages WHERE repository = ? AND categories = ? AND name = ? AND version = ? AND slot = ?', [@id,
						categories, name, version.to_s, slot.to_s
					]).first['id']

					@db.execute('INSERT OR REPLACE INTO binary_builds VALUES(?, ?, ?, ?)', [id, features, flavors, digest])

          @db.execute('INSERT OR IGNORE INTO binary_features VALUES(?, ?)', [id, build.parent['features']])
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

          @db.execute('INSERT OR REPLACE INTO packages VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [@id,
            package.categories.join('/'), package.name, package.version.to_s, package.slot.to_s, package.revision,
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

end