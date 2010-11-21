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

require 'packo/binary/models/repository/repository/package'

module Packo; module Binary; module Models; module Repository

class Repository
  include DataMapper::Resource

  property :id, Serial

  property :name, String,                 :required => true
  property :type, Enum[:binary, :source], :required => true

  property :uri,  Text, :required => true
  property :path, Text, :required => true

  has n, :packages

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

  def populate
    case type
      when :binary; _populate_binary(Nokogiri::XML.parse(File.read(path)).xpath('//packages').first)
      when :source; _populate_source([path], path)
    end
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

    conditions = {}

    op = exact ? :eql : :like

    conditions[Query::Operator.new(:categories, op)] = package.categories.join('/') if !package.categories.empty?
    conditions[Query::Operator.new(:name, op)]       = package.name if package.name
    conditions[Query::Operator.new(:version, op)]    = package.version if package.version
    conditions[Query::Operator.new(:slot, op)]       = package.slot if package.slot

    result = packages.all(conditions)

    return result if !validity

    result.select {|pkg|
      case validity
        when '>';  Versionomy.parse(pkg.version) >  package.version
        when '>='; Versionomy.parse(pkg.version) >= package.version
        when '<';  Versionomy.parse(pkg.version) <  package.version
        when '<='; Versionomy.parse(pkg.version) <= package.version
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
        e.xpath('.//build').each {|build|
          self.packages.create(
            :categories => categories,
            :name       => e['name'],
            :version    => build.parent['name'],
            :slot       => build.parent.parent['name'],
            :revision   => build.parent['revision'],

            :description => e['description'],
            :homepage    => e['homepage'],
            :license     => e['license']
          ))

          package.data.builds.create(
            :flavor   => (build.elements.xpath('.//flavor').first.text rescue nil)
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
          package = Packo::Binary::Package.new(categories, File.basename(what), version.match(/-(\d.*?)\.(rbuild|xml)$/)[1])

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

end; end; end; end
