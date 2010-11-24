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
require 'nokogiri'

module Packo

class Package

class Manifest
  def self.open (path)
    dom = Nokogiri::XML.parse(File.read(path))

    Manifest.new(OpenStruct.new(
      :tags    => Packo::Package::Tags.parse(dom.xpath('//package/tags').first.text),
      :name    => dom.xpath('//package/name').first.text,
      :version => Versionomy.parse(dom.xpath('//package/version').first.text),
      :slot    => dom.xpath('//package/slot').first.text,

      :flavors  => (dom.xpath('//package/flavor').first.text || '').split(/\s+/),
      :features => (dom.xpath('//package/features').first.text || '').split(/\s+/),

      :environment => Hash[dom.xpath('//package/environment/variable').map {|env|
        [env['name'], env.text]
      }],

      :dependencies => dom.xpath('//dependencies/dependency').map {|dependency|
        Dependency.parse("#{dependency.text}#{'!' if dependency['type'] == 'build'}")
      },

      :blockers => dom.xpath('//blockers/blocker').map {|blocker|
        Blocker.parse("#{blocker.text}#{'!' if blocker['type'] == 'build'}")
      },

      :selector => dom.xpath('//selectors/selector').map {|selector|
        Hash[
          :name        => selector['name'],
          :description => selector['description'],
          :path        => selector.text
        ]
      }
    ))
  end

  attr_reader :package, :dependencies, :blockers, :selectors

  def initialize (what)
    @package = OpenStruct.new(
      :name    => what.name,
      :tags    => what.tags,
      :version => what.version,
      :slot    => what.slot,

      :flavors  => what.flavors.to_a.select {|f| f.enabled?}.map {|f| f.name.to_s},
      :features => what.features.to_a.select {|f| f.enabled?}.map {|f| f.name.to_s},

      :environment => what.environment.reject {|name, value|
        [:PROFILE, :CONFIG_FILE, :CONFIG_PATH, :CONFIG_MODULES, :REPOSITORIES, :SELECTORS, :NO_COLORS, :DEBUG, :VERBOSE, :TMP].member?(name.to_sym)
      }
    )

    @dependencies = what.dependencies
    @blockers     = what.blockers
    @selectors    = [what.selector].flatten.compact.map {|selector| OpenStruct.new(selector)}

    @builder = Nokogiri::XML::Builder.new {|xml|
      xml.manifest(:version => '1.0') {
        xml.package {
          xml.tags     self.package.tags.to_s
          xml.name     self.package.name
          xml.version  self.package.version
          xml.slot     self.package.slot
          xml.revision self.package.revision

          xml.flavor   self.package.flavors.join(' ')
          xml.features self.package.features.join(' ')

          xml.environment {
            self.package.environment.each {|name, value|
              xml.variable({ :name => name }, value)
            }
          }
        }

        xml.dependencies {
          self.dependencies.each {|dependency|
            xml.dependency({ :type => (dependency.runtime?) ? 'runtime' : 'build' }, dependency.to_s)
          }
        }

        xml.blockers {
          self.blockers.each {|blocker|
            xml.blocker({ :type => (dependency.runtime?) ? 'runtime' : 'build' }, blocker.to_s)
          }
        }

        xml.selectors {
          self.selectors.each {|selector|
            xml.selector({ :name => selector.name, :description => selector.description }, File.basename(selector.path))
          }
        }
      }
    }
  end

  def save (to, options={})
    file = File.new(to, 'w')
    file.write(self.to_s(options))
    file.close
  end

  def to_s (options={})
    @builder.to_xml({ :indent => 4 }.merge(options))
  end
end

end

end
