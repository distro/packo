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
require 'base64'

require 'packo'

module Packo; module RBuild; class Package < Packo::Package

class Manifest
  def self.parse (text)
    dom = Nokogiri::XML.parse(text)

    Manifest.new(OpenStruct.new(
      :maintainer => dom.root['maintainer'],

      :tags    => Packo::Package::Tags.parse(dom.xpath('//package/tags').first.text),
      :name    => dom.xpath('//package/name').first.text,
      :version => Versionomy.parse(dom.xpath('//package/version').first.text),
      :slot    => dom.xpath('//package/slot').first.text,

      :exports => Marshal.load(Base64.decode64(dom.xpath('//package/exports').first.text)),

      :description => dom.xpath('//package/description').first.text,
      :homepage    => dom.xpath('//package/homepage').first.text.split(/\s+/),
      :license     => dom.xpath('//package/license').first.text.split(/\s+/),

      :flavor   => Packo::Package::Flavor.parse(dom.xpath('//package/flavor').first.text || ''),
      :features => Packo::Package::Features.parse(dom.xpath('//package/features').first.text || ''),

      :environment => Hash[dom.xpath('//package/environment/variable').map {|env|
        [env['name'], env.text]
      }],

      :dependencies => dom.xpath('//dependencies/dependency').map {|dependency|
        Package::Dependency.parse("#{dependency.text}#{['', '!', '!!'][['both', 'build', 'runtime'].index(dependency['type'])]}")
      },

      :blockers => dom.xpath('//blockers/blocker').map {|blocker|
        Package::Blocker.parse("#{blocker.text}#{['', '!', '!!'][['both', 'build', 'runtime'].index(dependency['type'])]}")
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

  def self.open (path)
    Manifest.parse(File.read(path))
  end

  attr_reader :package, :dependencies, :blockers, :selectors

  def initialize (what)
    @package = OpenStruct.new(
      :maintainer => what.maintainer,

      :tags    => what.tags,
      :name    => what.name,
      :version => what.version,
      :slot    => what.slot,

      :exports => what.exports,

      :description => what.description,
      :homepage    => [what.homepage].flatten.compact.join(' '),
      :license     => [what.license].flatten.compact.join(' '),

      :flavor   => what.flavor,
      :features => what.features,

      :environment => what.environment.reject {|name, value|
        [:DATABASE, :FLAVORS, :PROFILE, :CONFIG_FILE, :CONFIG_PATH,
         :CONFIG_MODULES, :REPOSITORIES, :SELECTORS, :FETCHER,
         :NO_COLORS, :DEBUG, :VERBOSE, :TMP, :SECURE
        ].member?(name.to_sym)
      }
    )

    @dependencies = what.dependencies
    @blockers     = what.blockers
    @selectors    = [what.selector].flatten.compact.map {|selector| OpenStruct.new(selector)}

    if (what.filesystem.selectors rescue false)
      what.filesystem.selectors.each {|name, file|
        matches = file.content.match(/^#\s*(.*?):\s*(.*)([\n\s]*)?\z/) or next

        @selectors << OpenStruct.new(:name => matches[1], :description => matches[2], :path => name)
      }
    end

    @builder = Nokogiri::XML::Builder.new {|xml|
      xml.manifest(:version => '1.0') {
        xml.package(:maintainer => self.package.maintainer) {
          xml.tags     self.package.tags
          xml.name     self.package.name
          xml.version  self.package.version
          xml.slot     self.package.slot
          xml.revision self.package.revision

          xml.description self.package.description
          xml.homepage    self.package.homepage
          xml.license     self.package.license

          xml.flavor   self.package.flavor
          xml.features self.package.features

          xml.environment {
            self.package.environment.each {|name, value|
              xml.variable({ :name => name }, value)
            }
          }

          xml.exports Base64.encode64(Marshal.dump(self.package.exports))
        }

        xml.dependencies {
          self.dependencies.each {|dependency|
            xml.dependency({ :type => dependency.type }, dependency.to_s)
          }
        }

        xml.blockers {
          self.blockers.each {|blocker|
            xml.blocker({ :type => blocker.type }, blocker.to_s)
          }
        }

        xml.selectors {
          self.selectors.each {|selector|
            xml.selector({ :name => selector.name, :description => selector.description }, selector.path)
          }
        }
      }
    }
  end

  def save (to, options={})
    File.write(to, self.to_s(options))
  end

  def to_s (options={})
    @builder.to_xml({ :indent => 4 }.merge(options))
  end
end

end; end; end
