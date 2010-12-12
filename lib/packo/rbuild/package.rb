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

require 'fffs'
require 'find'

require 'packo/package'

require 'packo/rbuild/do'
require 'packo/rbuild/dependencies'
require 'packo/rbuild/blockers'
require 'packo/rbuild/stages'
require 'packo/rbuild/features'
require 'packo/rbuild/flavor'
require 'packo/rbuild/package/manifest'

module Packo; module RBuild

class Package < Packo::Package
  @@packages = {}

  def self.last
    @@packages[:last]
  end

  undef :description, :homepage, :license

  include Stages::Callable

  def self.define (name, version=nil, slot=nil, revision=nil, &block)
    Package.new(name, version, slot, revision, &block)
  end

  attr_reader :parent, :environment, :do, :modules, :dependencies, :blockers, :stages, :filesystem

  def initialize (name, version=nil, slot=nil, revision=nil, &block)
    super(
      :name     => name,
      :version  => version,
      :slot     => slot,
      :revision => revision
    )

    @filesystem = FFFS::FileSystem.new

    ['pre', 'post', 'selectors', 'patches', 'files'].each {|dir|
      @filesystem << FFFS::Directory.new(dir)
    }

    @data = {}

    if !self.version
      @block = block
      
      return @@packages[:last] = self
    end

    @modules      = []
    @environment  = Environment.new(self)
    @do           = Do.new(self)
    @dependencies = Dependencies.new(self)
    @blockers     = Blockers.new(self)
    @stages       = Stages.new(self)
    @features     = Features.new(self)
    @flavor       = Flavor.new(self)

    @stages.add :dependencies, @dependencies.method(:check), :at => :beginning
    @stages.add :blockers,     @blockers.method(:check),     :at => :beginning

    behavior Behaviors::Default

    self.envify!

    if (@parent = Package.last)
      self.instance_exec(self, &@parent.instance_eval('@block'))
    end

    before :pack, :name => :headers do
      next if flavor.vanilla?

      if !flavor.headers?
        Find.find(distdir) {|file|
          if ['include', 'headers'].member?(File.basename(file)) && File.directory?(file)
            FileUtils.rm_rf(file, :secure => true) rescue nil
          end
        }
      end
    end

    before :pack, :name => :documentation do
      next if flavor.vanilla?

      if !flavor.documentation?
        Find.find(distdir) {|file|
          if ['man', 'info', 'doc'].member?(File.basename(file)) && File.directory?(file)
            FileUtils.rm_rf(file, :secure => true) rescue nil
          end
        }
      end
    end

    self.directory = "#{package.environment[:TMP]}/#{self.tags.to_s(true)}/#{@name}/#{@slot}/#{@version}".gsub(%r{/*/}, '/')
    self.workdir   = "#{package.directory}/work"
    self.distdir   = "#{package.directory}/dist"
    self.tempdir   = "#{package.directory}/temp"

    stages.callbacks(:initialize).do(self) {
      self.instance_exec(self, &block) if block
    }

    features.each {|feature|
      next unless feature.enabled?

      feature.needs.each {|need|
        if tmp = need.match(/^-(.+)$/) && features.get(tmp[1]).enabled?
          Packo.warn "Feature #{feature} can't be enabled with #{tmp[1]}, disabling."
          feature.disable!
        else
          Packo.warn "Feature #{feature} needs #{need}, disabling"
          feature.disable!
        end
      }
    }

    @@packages.clear
    @@packages[:last] = self
  end

  def create!
    FileUtils.mkpath self.workdir
    FileUtils.mkpath self.distdir
    FileUtils.mkpath self.tempdir
  rescue; end

  def clean!
    FileUtils.rm_rf self.workdir, :secure => true
    FileUtils.rm_rf self.distdir, :secure => true
    FileUtils.rm_rf self.tempdir, :secure => true
  rescue; end

  def envify!
    environment[:FLAVOR].split(/\s+/).each {|element|
      matches = element.match(/^([+-])?(.+)$/)

      (matches[1] == '-') ?
        self.flavor.send("not_#{matches[2]}!") :
        self.flavor.send("#{matches[2]}!")
    }

    environment[:FEATURES].split(/\s+/).each {|feature|
      feature = Feature.parse(feature)

      self.features {
        next if !self.has?(feature.name)

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

  def avoid (klass)
    [klass].flatten.each {|klass|
      @modules.unregister(klass).finalize rescue nil
    }
  end

  def behavior (uses)
    uses.each {|use|
      self.use(use)
    }
  end

  def tags (*value)
    value.flatten.compact.empty? ? @tags : self.tags = value
  end

  def features (&block)
    block.nil? ? @features : @features.instance_eval(&block)
  end

  def flavor (&block)
    if !block
      @flavor
    else
      @flavor.instance_eval &block
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
      when :package;    "#{@name}-#{@version}#{"%#{@slot}" if @slot}#{"+#{@flavor.to_s(:package)}" if !@flavor.to_s.empty?}#{"-#{@features.to_s(:package)}" if !@features.to_s(:package).empty?}"
      when :everything; "#{super(:whole)} #{self.environment.reject {|n| n == :DEBUG}.to_s }}"
      else              "#{super(:whole)}#{"[#{@features.to_s}]" if !@features.to_s.empty?}#{"{#{@flavor.to_s}}" if !@flavor.to_s.empty?}"
    end
  end
end

end; end
