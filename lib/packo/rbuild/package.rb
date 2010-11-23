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

require 'packo/rbuild/packages'

require 'packo/rbuild/dependencies'
require 'packo/rbuild/blockers'
require 'packo/rbuild/stages'
require 'packo/rbuild/features'
require 'packo/rbuild/flavor'

module Packo; module RBuild

class Package < Packo::Package
  def self.define (name, version=nil, slot=nil, revision=nil, &block)
    Package.new(name, version, slot, revision, &block)
  end

  attr_reader :environment, :modules, :dependencies, :blockers, :stages

  def initialize (categories, name, version=nil, slot=nil, revision=nil, &block)
    super(
      :name       => categories,
      :categories => name,
      :version    => version,
      :slot       => slot,
      :revision   => revision
    )

    Packages[self.to_s(:whole)] = self
    Packages[:last] = self

    if !self.version || !(tmp = Packages[self.to_s(:name)])
      @modules      = []
      @dependencies = Packo::Dependencies.new(self)
      @blockers     = Packo::Blockers.new(self)
      @stages       = Packo::Stages.new(self)
      @features     = Packo::Features.new(self)
      @flavor       = Packo::Flavors.new(self)
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

      @flavor = Flavors.new(self)

      @dependencies.owner = self
      @blockers.owner     = self
      @stages.owner       = self
      @features.owner     = self
      @flavors.owner      = self
    end

    @stages.add :dependencies, @dependencies.method(:check), :at => :beginning
    @stages.add :blockers, @blockers.method(:check), :at => :beginning

    @environment = Environment.new(self)

    self.directory = "#{package.environment['TMP']}/#{self.to_s(:whole)}/#{@version}"
    self.workdir   = "#{package.directory}/work"
    self.distdir   = "#{package.directory}/dist"
    self.tempdir   = "#{package.directory}/temp"

    @default_to_self = true
    @stages.call :initialize, self
    self.instance_exec(self, &block) if block
    @stages.call :initialized, self
    @default_to_self = false

    self.envify!
  end

  def create!
    FileUtils.mkpath self.workdir
    FileUtils.mkpath self.distdir
    FileUtils.mkpath self.tempdir
  rescue; end

  def envify!
    ['headers', 'documentation', 'debug', 'minimal', 'vanilla'].each {|flavor|
      if Packo::Environment[:FLAVOR].include?(flavor)
        self.flavors.send "#{flavor}!"
      else
        self.flavors.send "not_#{flavor}!"
      end
    }

    Packo::Environment[:FEATURES].split(/\s+/).each {|feature|
      feature = Packo::Feature.parse(feature)

      self.features {
				next if !self.has(feature.name)

				(feature.enabled?) ?
        	self.get(feature.name).enabled! :
					self.get(feature.name).disabled!
      }
    }
  end

  def build
    self.create!

    @build_start_at = Time.now

    if (error = @stages.call(:build, self).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end

    @stages.each {|stage|
      yield stage if block_given?

      stage.call
    }

    @stages.call :build!, self

    @build_end_at = Time.now
  end

  def build?
    Hash[
      :start => @build_start_at,
      :end   => @build_end_at
    ] if @build_start_at
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

  def flavor (&block)
    if !block
      @flavor
    else
      @flavor.instance_eval &block
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

  def to_s (type=nil)
    return result if (result = super(type))

    case type
      when :package; "#{@name}-#{@version}#{"%#{@slot}" if @slot}#{"+#{@flavor.to_s(true)}" if !@flavor.to_s(true).empty?}#{"-#{@features.to_s(true)}" if !@features.to_s(true).empty?}"
      else           "#{super(:whole)}#{"[#{@features.to_s}]" if !@features.to_s.empty?}#{"{#{@flavor.to_s}}" if !@flavor.to_s.empty?}"
    end
  end
end

end; end
