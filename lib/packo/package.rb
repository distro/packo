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

require 'packo/packages'

require 'packo/dependencies'
require 'packo/blockers'
require 'packo/stages'
require 'packo/features'
require 'packo/flavors'

module Packo

class Package
  def self.parse (text)
    result = OpenStruct.new

    matches = text.match(/^(.*?)(\[(.*?)\])?(\{(.*?)\})?$/)

    result.features = Hash[(matches[3] || '').split(/\s*,\s*/).map {|feature|
      if feature[0] == '-'
        [feature[1, feature.length], false]
      else
        [(feature[0] == '+' ? feature[1, feature.length] : feature), true]
      end
    }]

    result.flavors = (matches[5] || '').split(/\s*,\s*/)

    matches = matches[1].match(/^(.*?)(-(\d.*))?$/)

    result.categories = matches[1].split('/')

    if matches[1][matches[1].length - 1] != '/'
      result.name = result.categories.pop
    end

    result.version = matches[3]

    return result
  end

  attr_reader :environment, :name, :categories, :version, :slot, :modules, :dependencies, :blockers, :stages

  def initialize (name, version=nil, slot=nil, &block)
    tmp         = name.split('/')
    @name       = tmp.pop
    @categories = tmp
    @version    = version.is_a?(Versionomy) ? version : Versionomy.parse(version.to_s) if version
    @slot       = slot

    Packages["#{(@categories + [@name]).join('/')}#{"-#{@version}" if @version}"] = self

    if !version || !(tmp = Packages[(@categories + [@name]).join('/')])
      @modules      = []
      @dependencies = Packo::Dependencies.new(self)
      @blockers     = Packo::Blockers.new(self)
      @stages       = Packo::Stages.new(self)
      @features     = Packo::Features.new(self)
      @flavors      = Packo::Flavors.new(self)
      @data         = {}
      @pre          = []
      @post         = []
    else
      @modules      = tmp.instance_eval('@modules.clone')
      @dependencies = tmp.instance_eval('@dependencies.clone')
      @blockers     = tmp.instance_eval('@blockers.clone')
      @stages       = tmp.instance_eval('@stages.clone')
      @features     = tmp.instance_eval('@features.clone')
      @flavors      = tmp.instance_eval('@flavors.clone')
      @data         = tmp.instance_eval('@data.clone')
      @pre          = tmp.instance_eval('@pre.clone')
      @post         = tmp.instance_eval('@post.clone')

      @modules.each {|mod|
        mod.owner = self
      }

      @flavors = Flavors.new(self)

      @dependencies.owner = self
      @blockers.owner     = self
      @stages.owner       = self
      @features.owner     = self
      @flavors.owner      = self
    end

    @stages.add :dependencies, @dependencies.method(:check), :at => :beginning
    @stages.add :blockers, @blockers.method(:check), :at => :beginning

    @environment = Environment.new

    self.directory = "#{package.environment['TMP']}/#{(@categories + [@name]).join('/')}/#{@version}"
    self.workdir   = "#{package.directory}/work"
    self.distdir   = "#{package.directory}/dist"

    @default_to_self = true
    @stages.call :initialize, self
    self.instance_exec(self, &block) if block
    @stages.call :initialized, self
    @default_to_self = false
  end

  def create!
    FileUtils.mkpath "#{self.directory}/"
    FileUtils.mkpath "#{self.directory}/work"
    FileUtils.mkpath "#{self.directory}/dist"
  rescue; end

  def build
    self.create!

    @stages.each {|stage|
      yield stage if block_given?

      stage.call
    }
  end

  def use (klass)
    @modules << klass.new(self)
  end
  
  def behavior (uses)
    uses.each {|use|
      self.use(use)
    }
  end

  def features (&block)
    if !block
      @features
    else
      @features.instance_eval &block
    end
  end

  def flavors (&block)
    if !block
      @flavors
    else
      @flavors.instance_eval &block
    end
  end

  def on (what, priority=0, binding=nil, &block)
    @stages.register(what, priority, block, binding || @default_to_self ? self : nil)
  end

  def pre (name=nil, content=nil)
    if !name || !content
      @pre
    else
      @pre << { :name => name, :content => content.lines.map {|line| line.strip}.join("\n") }
    end
  end

  def post (name=nil, content=nil)
    if !name || !content
      @post
    else
      @post << { :name => name, :content => content.lines.map {|line| line.strip}.join("\n") }
    end
  end

  def method_missing (id, *args)
    id = id.to_s.sub(/=$/, '').to_sym

    if args.length == 0
      return @data[id]
    else
      @data[id] = (args.length > 1) ? args : args.first
    end
  end

  def package; self end

  def to_xml
    <<XML

<?xml version="1.0" encoding="utf-8"?>

<package>
    <name>#{@name}</name>
    <version>#{@version}</version>
  
    <categories>
#{@categories.map {|category|
  "        <category>#{category}</category>"
}.join("\n")}
    </categories>

    <dependencies>
#{@dependencies.each {|dependency|
  "        <dependency type='#{dependency.runtime? ? 'runtime' : 'build'}'>#{dependency.to_s}</dependency>"
}.join("\n")}
    </dependencies>
</package>

XML
  end

  def to_s (pack=false)
    if pack && @version
      "#{@name}-#{@version}#{"+#{@flavors.to_s(true)}" if !@flavors.to_s(true).empty?}#{"-#{@features.to_s(true)}" if !@features.to_s(true).empty?}#{".#{@slot}" if @slot}"
    else
      "#{(@categories + [@name]).join('/')}#{"-#{@version}" if @version}#{"[#{@features.to_s}]" if !@features.to_s.empty?}#{"{#{@flavors.to_s}}" if !@flavors.to_s.empty?}"
    end
  end
end

end
