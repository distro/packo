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

class Package

class Manifest
  def self.open (path)
    dom = REXML::Document.new(File.new(path))

    Manifest.new(OpenStruct.new(
      :name       => dom.elements.each('//package/name') {}.first.text,
      :categories => dom.elements.each('//package/categories') {}.first.text.split('/'),
      :version    => dom.elements.each('//package/version') {}.first.text,
      :slot       => dom.elements.each('//package/slot') {}.first.text,

      :dependencies => dom.elements.each('//dependencies/dependency') {}.map {|dependency|
        Dependency.parse("#{dependency}#{'!' if dependency.attributes['type'] == 'build'}")
      },

      :blockers => dom.elements.each('//blockers/blocker') {}.map {|blocker|
        Blocker.parse(blocker)
      },

      :selector => dom.elements.each('//selectors/selector') {}.map {|selector|
        Hash[
          :name        => selector.attributes['name'],
          :description => selector.attributes['description'],
          :path        => selector.text
        ]
      }
    ))
  end

  attr_reader :package, :dependencies, :blockers, :selectors

  def initialize (what)
    @package = OpenStruct.new(
      :name       => what.name,
      :categories => what.categories,
      :version    => what.version,
      :slot       => what.slot
    )

    @dependencies = what.dependencies
    @blockers     = what.blockers
    @selectors    = [what.selector].flatten

    self.xmlify!
  end

  def xmlify!
    @dom = REXML::Document.new
    @dom.add_element REXML::Element.new('manifest')
    @dom.root.attributes['version'] = '1.0'

    package = REXML::Element.new('package')
    package.add_element((dom = REXML::Element.new('name'); dom.text = self.package.name; dom))
    package.add_element((dom = REXML::Element.new('categories'); dom.text = self.package.categories.join('/'); dom))
    package.add_element((dom = REXML::Element.new('version'); dom.text = self.package.version.to_s; dom))
    package.add_element((dom = REXML::Element.new('slot'); dom.text = self.package.slot; dom))

    dependencies = REXML::Element.new('dependencies')
    self.dependencies.each {|dependency|
      dependencies.add_element((dom = REXML::Element.new('dependency');
        dom.attributes['runtime'] = (dependency.runtime?) ? 'runtime' : 'build';
        dom.text                  = dependency.to_s;
        dom
      ))
    }

    blockers = REXML::Element.new('blockers')
    self.blockers.each {|blocker|
      blockers.add_element((dom = REXML::Element.new('blocker');
        dom.text = blocker.to_s
        dom
      ))
    }

    selectors = REXML::Element.new('selectors')
    self.selectors.each {|selector|
      selectors.add_element((dom = REXML::Element.new('selector');
        dom.attributes['name']        = selector[:name];
        dom.attributes['description'] = selector[:description];
        dom.text                      = File.basename(selector[:path]);
        dom
      ))
    }

    @dom.root.add_element package
    @dom.root.add_element dependencies
    @dom.root.add_element blockers
    @dom.root.add_element selectors
  end

  def save (to, *args)
    file = File.new(to, 'w')
    file.write(self.to_s(*args))
    file.close
  end

  def to_s (*args)
    result = ''
    @dom.write(result, *args)
    result
  end
end

end

end
