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

require 'packo/dependencies'
require 'packo/stages'
require 'packo/features'
require 'packo/flavors'

module Packo

class Package
  @@roots = {}

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

    tmp               = matches[1].split('/')
    result.name       = tmp.pop
    result.categories = tmp

    result.version = matches[3]

    return result
  end

  attr_reader :name, :categories, :version, :modules, :dependencies, :features, :flavors, :stages

  def initialize (name, version=nil, &block)
    tmp         = name.split('/')
    @name       = tmp.pop
    @categories = tmp
    @version    = version

    if !version
      @@roots[(@categories + [@name]).join('/')] = self
    end

    if !version || !(tmp = @@roots[(@categories + [@name]).join('/')])
      @modules      = []
      @dependencies = Packo::Dependencies.new(self)
      @stages       = Packo::Stages.new(self)
      @features     = Packo::Features.new(self)
      @data         = {}
      @pre          = []
      @post         = []
    else
      @modules      = tmp.instance_eval('@modules.clone')
      @dependencies = tmp.instance_eval('@dependencies.clone')
      @stages       = tmp.instance_eval('@stages.clone')
      @features     = tmp.instance_eval('@features.clone')
      @data         = tmp.instance_eval('@data.clone')
      @pre          = tmp.instance_eval('@pre.clone')
      @post         = tmp.instance_eval('@post.clone')

      @modules.each {|mod|
        mod.owner = self
      }

      @flavors = Flavors.new(self)

      @dependencies.owner = self
      @stages.owner       = self
      @features.owner     = self

      self.directory = "#{Packo.env('TMP') || '/tmp'}/#{(@categories + [@name]).join('/')}/#{@version}"

      FileUtils.mkpath "#{self.directory}/"
      FileUtils.mkpath "#{self.directory}/work"
      FileUtils.mkpath "#{self.directory}/dist"

      @stages.call :initialize, self
    end

    @stages.add :dependencies, @dependencies.method(:check), :at => :beginning

    self.instance_exec(self, &block) if block
  end

  def build
    @stages.each {|stage|
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
    @features.instance_eval &block
  end

  def on (what, priority=0, &block)
    @stages.register(what, priority, block)
  end

  def pre (name=nil, content=nil)
    if !name || !content
      @pre
    else
      @pre << { :name => name, :content => content }
    end
  end

  def post (name=nil, content=nil)
    if !name || !content
      @post
    else
      @post << { :name => name, :content => content }
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
  "        <dependency type='#{(dependency.build? ? 'build' : 'runtime'}'>#{dependency.to_s}</dependency>"
}.join("\n")}
    </dependencies>
</package>

XML
  end

  def to_s (pack=false)
    if pack && @version
      "#{@name}-#{@version}-#{@flavors.to_s(true)}-#{@features.to_s(true)}"
    else
      "#{(@categories + [@name]).join('/')}#{"-#{@version}" if @version}#{"[#{@features.to_s}]" if !@features.to_s.empty?}"
    end
  end
end

end
