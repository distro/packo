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

require 'packo/package'

require 'packo/rbuild/dependencies'
require 'packo/rbuild/blockers'
require 'packo/rbuild/stages'
require 'packo/rbuild/features'
require 'packo/rbuild/flavor'

module Packo; module RBuild

Packages = Class.new(Hash) {

}.new

class Package < Packo::Package
  undef :description, :homepage, :license

  include Stages::Callable

  def self.define (name, version=nil, slot=nil, revision=nil, &block)
    Package.new(name, version, slot, revision, &block)
  end

  attr_reader :environment, :modules, :dependencies, :blockers, :stages

  def initialize (tags, name, version=nil, slot=nil, revision=nil, &block)
    super(
      :tags     => tags,
      :name     => name,
      :version  => version,
      :slot     => slot,
      :revision => revision
    )

    @data = {}

    Packages[self.to_s(:whole)] = self
    Packages[:last] = self

    if !self.version || !(tmp = Packages[self.to_s(:name)])
      @modules      = []
      @dependencies = Dependencies.new(self)
      @blockers     = Blockers.new(self)
      @stages       = Stages.new(self)
      @features     = Features.new(self)
      @flavor       = Flavor.new(self)
      @data         = {}
      @pre          = []
      @post         = []
    else
      @modules      = tmp.instance_eval('@modules.clone')
      @dependencies = tmp.instance_eval('@dependencies.clone')
      @blockers     = tmp.instance_eval('@blockers.clone')
      @stages       = tmp.instance_eval('@stages.clone')
      @features     = tmp.instance_eval('@features.clone')
      @flavor       = tmp.instance_eval('@flavor.clone')
      @data         = tmp.instance_eval('@data.clone')
      @pre          = tmp.instance_eval('@pre.clone')
      @post         = tmp.instance_eval('@post.clone')

      @modules.each {|mod|
        mod.owner = self
      }

      @dependencies.owner = self
      @blockers.owner     = self
      @stages.owner       = self
      @features.owner     = self
      @flavor.owner       = self
    end

    @stages.add :dependencies, @dependencies.method(:check), :at => :beginning
    @stages.add :blockers, @blockers.method(:check), :at => :beginning

    @environment = Environment.new(self)

    self.directory = "#{package.environment['TMP']}/#{self.to_s(:whole)}/#{@version}"
    self.workdir   = "#{package.directory}/work"
    self.distdir   = "#{package.directory}/dist"
    self.tempdir   = "#{package.directory}/temp"

    @default_to_self = true

    stages.callbacks(:initialize).do(self) {
      self.instance_exec(self, &block) if block
    }

    @default_to_self = false

    self.envify!
  end

  def create!
    FileUtils.mkpath self.workdir
    FileUtils.mkpath self.distdir
    FileUtils.mkpath self.tempdir
  rescue; end

  def envify!
    Flavor::Names.each {|flavor|
      if Environment[:FLAVOR].include?(flavor.to_s)
        self.flavor.send "#{flavor}!"
      else
        self.flavor.send "not_#{flavor}!"
      end
    }

    Environment[:FEATURES].split(/\s+/).each {|feature|
      feature = Feature.parse(feature)

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

    stages.callbacks(:build).do(self) {
      stages.each {|stage|
        yield stage if block_given?

        stage.call
      }
    }

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
    return super(type) if super(type)

    case type
      when :package; "#{@name}-#{@version}#{"%#{@slot}" if @slot}#{"+#{@flavor.to_s}" if !@flavor.to_s.empty?}#{"-#{@features.to_s}" if !@features.to_s.empty?}"
      else           "#{super(:whole)}#{"[#{@features.to_s}]" if !@features.to_s.empty?}#{"{#{@flavor.to_s}}" if !@flavor.to_s.empty?}"
    end
  end
end

end; end
