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
require 'packo/package/dependencies'
require 'packo/package/blockers'

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

  include Stages::Callable

  def self.define (name, version=nil, slot=nil, revision=nil, &block)
    Package.new(name, version, slot, revision, &block)
  end

  attr_reader :parent, :do, :modules, :dependencies, :blockers, :stages, :filesystem

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

    if !self.version
      @block = block

      return @@packages[:last] = self
    end

    @modules      = []
    @stages       = Stages.new(self)
    @do           = Do.new(self)
    @dependencies = Dependencies.new(self)
    @blockers     = Blockers.new(self)
    @features     = Features.new(self)
    @flavor       = Flavor.new(self)

    @stages.add :dependencies, self.method(:dependencies_check), :at => :beginning
    @stages.add :blockers,     self.method(:blockers_check),     :at => :beginning

    behavior Behaviors::Default
    use      Modules::Packaging::PKO

    if (@parent = Package.last)
      self.instance_exec(self, &@parent.instance_eval('@block'))
    end

    flavor {
      vanilla {
        description 'Apply only the patches needed to build succesfully the package'

        needs :not, :documentation, :headers, :debug
      }

      documentation {
        description 'Add documentation to the package'

        before :pack, :name => :documentation do
          next if flavor.vanilla?

          if !enabled?
            Find.find(distdir) {|file|
              if ['man', 'info', 'doc'].member?(File.basename(file)) && File.directory?(file)
                FileUtils.rm_rf(file, :secure => true) rescue nil
              end
            }
          end
        end
      }

      headers {
        description 'Add headers to the package'

        before :pack, :name => :headers do
          next if flavor.vanilla?

          if !enabled?
            Find.find(distdir) {|file|
              if ['include', 'headers'].member?(File.basename(file)) && File.directory?(file)
                FileUtils.rm_rf(file, :secure => true) rescue nil
              end
            }
          end
        end
      }

      debug {
        description 'Make a debug build'
      }
    }

    self.directory = Pathname.new("#{package.env[:TMP]}/#{tags.to_s(true)}/#{name}/#{slot}/#{version}").cleanpath.to_s
    self.workdir   = "#{package.directory}/work"
    self.distdir   = "#{package.directory}/dist"
    self.tempdir   = "#{package.directory}/temp"

    stages.callbacks(:initialize).do(self) {
      self.instance_exec(self, &block) if block
    }

    self.envify!
    self.export! :arch, :kernel, :compiler, :libc

    flavor.dup.each {|element|
      next unless element.enabled?

      element.needs.dup.each {|need|
        if tmp = need.match(/^-(.+)$/)
          if element.get(tmp[1]).enabled?
            element.disable!

            if System.env[:VERBOSE]
              require 'packo/cli'
              CLI.warn "Flavor #{element} can't be enabled with #{tmp[1]}, disabling."
            end
          end
        elsif flavor.get(need).disabled?
          element.disable!

          if System.env[:VERBOSE]
            require 'packo/cli'
            CLI.warn "Flavor #{element} needs #{need}, disabling"
          end
        end
      }
    }

    features.dup.each {|feature|
      next unless feature.enabled?

      feature.needs.dup.each {|need|
        if tmp = need.match(/^-(.+)$/)
          if features.get(tmp[1]).enabled?
            feature.disable!

            if System.env[:VERBOSE]
              require 'packo/cli'
              CLI.warn "Feature #{feature} can't be enabled with #{tmp[1]}, disabling."
            end
          end
        elsif features.get(need).disabled?
          feature.disable!

          if System.env[:VERBOSE]
            require 'packo/cli'
            CLI.warn "Feature #{feature} needs #{need}, disabling"
          end
        end
      }
    }

    stages.callbacks(:initialized).do(self)

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

  def dependencies_check
    stages.callbacks(:dependencies).do(self)
  end

  def blockers_check
    stages.callbacks(:blockers).do(self)
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
    [klass].flatten.compact.each {|klass|
      @modules.delete(@modules.find {|mod|
        mod.class == klass
      }).finalize rescue nil
    }
  end

  def behavior (uses)
    uses.each {|use|
      self.use(use)
    }
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

  def package; self end

  def to_s (type=nil)
    return super(type) if super(type)

    case type
      when :package;    "#{name}-#{version}#{"%#{slot}" if slot}#{"+#{@flavor.to_s(:package)}" if !@flavor.to_s(:package).empty?}#{"-#{@features.to_s(:package)}" if !@features.to_s(:package).empty?}"
      when :everything; "#{super(:whole)} #{package.env!.reject {|n| n == :DEBUG}.to_s }}"
      else              "#{super(:whole)}#{"[#{@features.to_s}]" if !@features.to_s.empty?}#{"{#{@flavor.to_s}}" if !@flavor.to_s.empty?}"
    end
  end
end

end; end
