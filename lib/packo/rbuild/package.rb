#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

require 'packo'

require 'packo/rbuild/stages'
require 'packo/rbuild/features'
require 'packo/rbuild/flavor'
require 'packo/rbuild/package/manifest'

require 'packo/rbuild/modules'
require 'packo/rbuild/behaviors'

module Packo; module RBuild

class Package < Packo::Package
  def self.current
    @current
  end

  def self.define (name, version=nil, slot=nil, revision=nil, &block)
    @current = Package.new(name, version, slot, revision, &block)
  end

  include Stages::Callable

  attr_reader :parent, :do, :modules, :dependencies, :blockers, :stages, :filesystem

  def initialize (name, version=nil, slot=nil, revision=nil, &block)
    super(
      name:     name,
      version:  version,
      slot:     slot,
      revision: revision
    )

    @filesystem = FFFS::FileSystem.new

    ['pre', 'post', 'selectors', 'patches', 'files'].each {|dir|
      @filesystem << FFFS::Directory.new(dir)
    }

    ['pre', 'post'].each {|dir|
      ['install', 'uninstall'].each {|target|
        @filesystem[dir] << FFFS::Directory.new(target)
      }
    }

    if !self.version
      @block = block

      return self
    end

    @modules      = []
    @stages       = Stages.new(self)
    @do           = Do.new(self)
    @dependencies = Dependencies.new(self)
    @blockers     = Blockers.new(self)
    @features     = Features.new(self)
    @flavor       = Flavor.new(self)

    @stages.add :dependencies, self.method(:dependencies_check), at: :beginning
    @stages.add :blockers,     self.method(:blockers_check),     at: :beginning

    use      Modules::Fetcher, Modules::Unpacker, Modules::Packager
    behavior Behaviors::Default

    if (@parent = Package.current)
      self.instance_exec(self, &@parent.instance_eval('@block'))
    end

    flavor {
      vanilla {
        description 'Apply only the patches needed to build succesfully the package'

        after :initialized do
          next unless enabled?

          flavor.each {|element|
            next if element.name == :vanilla

            element.disable!
          }
        end
      }

      documentation {
        description 'Add documentation to the package'

        before :pack, name: :documentation do
          next if flavor.vanilla?

          if !enabled?
            Find.find(distdir) {|file|
              if ['man', 'info', 'doc'].member?(File.basename(file)) && File.directory?(file)
                FileUtils.rm_rf(file, secure: true) rescue nil
              end
            }
          end
        end
      }

      headers {
        description 'Add headers to the package'

        before :pack, name: :headers do
          next if flavor.vanilla?

          if !enabled?
            Find.find(distdir) {|file|
              if ['include', 'headers'].member?(File.basename(file)) && File.directory?(file)
                FileUtils.rm_rf(file, secure: true) rescue nil
              end
            }
          end
        end
      }

      debug {
        description 'Make a debug build'
      }
    }

    self.directory = Path.clean("#{package.env[:TMP]}/#{tags.to_s(true)}/#{name}/#{slot}/#{version}")
    self.workdir   = "#{package.directory}/work"
    self.distdir   = "#{package.directory}/dist"
    self.tempdir   = "#{package.directory}/temp"
    self.fetchdir  = System.env[:FETCH_PATH] || self.tempdir

    stages.callbacks(:initialize).do(self) {
      self.instance_exec(self, &block) if block
    }

    self.envify!
    self.export! :arch, :kernel, :compiler, :libc

    tmp = []
    features.each {|feature|
      next unless feature.enabled?

      tmp << feature.name
    }

    features.each {|feature|
      next unless feature.enabled? && feature.needs

      expression = Packo::Package::Tags::Expression.parse(feature.needs)

      if !expression.evaluate(tmp)
        raise Package::Tags::Expression::EvaluationError.new "#{self.to_s :name}: could not ensure `#{expression}` for `#{feature.name}`"
      end
    }

    stages.callbacks(:initialized).do(self)

    return self
  end

  def create!
    FileUtils.mkpath self.workdir
    FileUtils.mkpath self.distdir
    FileUtils.mkpath self.tempdir
  rescue; end

  def clean!
    FileUtils.rm_rf self.workdir, secure: true
    FileUtils.rm_rf self.distdir, secure: true
    FileUtils.rm_rf self.tempdir, secure: true
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

    Do.cd {
      stages.callbacks(:build).do(self) {
        stages.each {|stage|
          yield stage if block_given?

          stage.call
        }
      }
    }

    @build_end_at = Time.now
  end

  def build?
    Hash[
      start: @build_start_at,
      end:   @build_end_at
    ] if @build_start_at
  end

  def use (*modules)
    modules.flatten.compact.each {|klass|
      @modules << klass.new(self)
    }
  end

  def avoid (*modules)
    modules.flatten.compact.each {|klass|
      @modules.delete(@modules.find {|mod|
        mod.class == klass
      }).finalize rescue nil
    }
  end

  def behavior (behavior)
    if @behavior
      avoid @behavior
    end

    (@behavior = behavior).each {|use|
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
