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

require 'packo/rbuild/stages'
require 'packo/rbuild/features'
require 'packo/rbuild/flavor'

require 'packo/rbuild/modules'
require 'packo/rbuild/behaviors'

module Packo; module RBuild

class Package < Packo::Package
  def self.current
    @@current
  end

  def self.define (name, version=nil, slot=nil, revision=nil, &block)
    @@current = self.new(name, version, slot, revision, &block)
  end

  def self.load (path, package=nil)
    options = {
      before: %{
        module ::Packo::RBuild
        include ::Packo::RBuild::Modules
        include ::Packo::RBuild::Behaviors
      },

      after: %{
        end
      }
    }

    files = {}

    if package
      if File.exists?("#{path}/digest.yml") && (digest = YAML.parse_file("#{path}/digest.yml").transform)
        pkg = digest['packages'].find {|pkg|
          pkg['version'] == package.version && (!package.slot || pkg['slot'] == package.slot)
        }

        if pkg && pkg['files']
          pkg['files'].each {|file|
            tmp = OpenStruct.new(file)

            files[file['name']] = tmp
            files[file['url']]  = tmp
          }
        end
      end

      begin
        Packo.load "#{path}/#{package.name}.rbuild", options

        if (pkg = self.current) && (tmp = File.read("#{path}/#{package.name}.rbuild", encoding: 'utf-8').split(/^__END__$/)).length > 1
          pkg.filesystem.parse(tmp.last.lstrip)
        end
      rescue Exception => e
        Packo.debug e
      end

      Packo.load "#{path}/#{package.name}-#{package.version}.rbuild", options

      if self.current.name == package.name && self.current.version == package.version
        self.current.filesystem.include(pkg.filesystem)

        if (tmp = File.read("#{path}/#{package.name}-#{package.version}.rbuild", encoding: 'utf-8').split(/^__END__$/)).length > 1
          self.current.filesystem.parse(tmp.last.lstrip)
        end

        if File.directory?("#{path}/data")
          self.current.filesystem.load("#{path}/data")
        end

        self.current.digests = files
      end
    else
      begin
        Packo.load path, options

        if (pkg = self.current) && (tmp = File.read(path, encoding: 'utf-8').split(/^__END__$/)).length > 1
          pkg.filesystem.parse(tmp.last.lstrip)
        end
      rescue Exception => e
        Packo.debug e
      end
    end

    self.current
  end

  include Callbackable

  attr_reader :parent, :do, :modules, :dependencies, :stages, :filesystem

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
    @features     = Features.new(self)
    @flavor       = Flavor.new(self)

    @stages.add :dependencies, self.method(:dependencies_check), at: :beginning

    use      Modules::Fetcher, Modules::Unpacker, Modules::Packager
    behavior Behaviors::Default

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

    if (@parent = Package.current)
      self.apply(&@parent.instance_eval('@block'))
    end

    self.directory = Path.clean("#{package.env[:TMP]}/#{tags.to_s(true)}/#{name}/#{slot}/#{version}")
    self.workdir   = "#{package.directory}/work"
    self.distdir   = "#{package.directory}/dist"
    self.tempdir   = "#{package.directory}/temp"
    self.fetchdir  = System.env[:FETCH_PATH] || self.tempdir

    callbacks(:initialize).do(self) {
      self.apply(&block)
    }

    self.envify!
    self.export! :arch, :kernel, :compiler, :libc

    [flavor, features].each {|thing|
      tmp = []
      thing.each {|piece|
        next unless piece.enabled?

        tmp << piece.name
      }

      if thing.needs && !(expression = Packo::Package::Tags::Expression.parse(thing.needs)).evaluate(tmp)
        raise Package::Tags::Expression::EvaluationError.new "#{self.to_s :name}: could not ensure `#{expression}` for the #{thing.class.name.match(/(?:::)?([^:]*)$/)[1].downcase}"
      end

      thing.each {|piece|
        next unless piece.enabled? && piece.needs

        if !(expression = Packo::Package::Tags::Expression.parse(piece.needs)).evaluate(tmp)
          raise Package::Tags::Expression::EvaluationError.new "#{self.to_s :name}: could not ensure `#{expression}` for `#{piece.name}`"
        end
      }
    }

    callbacks(:initialized).do(self)
  end

  def apply (text=nil, &block)
    if text
      if (tmp = text.split(/^__END__$/)).length > 1
        filesystem.parse(tmp.last.lstrip)
      end
    end

    super
  end

  def create!
    FileUtils.mkpath self.workdir
    FileUtils.mkpath self.distdir
    FileUtils.mkpath self.tempdir
  rescue; end

  def clean! (full=true)
    FileUtils.rm_rf self.distdir, secure: true

    if full
      FileUtils.rm_rf self.workdir, secure: true
      FileUtils.rm_rf self.tempdir, secure: true
    end
  rescue; end

  def dependencies_check
    callbacks(:dependencies).do(self)
  end

  def build
    self.create!

    @build_start_at = Time.now

    Do.cd {
      callbacks(:build).do(self) {
        stages.each {|stage|
          yield stage if block_given?

          stage.call
        }
      }
    }

    @build_end_at = Time.now
  end

  def built?
    OpenStruct.new(
      start: @build_start_at,
      end:   @build_end_at
    ) if @build_start_at
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

  def selectors
    filesystem.selectors.map {|name, file|
      matches = file.content.match(/^#\s*(.*?):\s*(.*)([\n\s]*)?\z/) or next

      OpenStruct.new(name: matches[1], description: matches[2], path: name)
    }.compact
  end

  def size
    result = 0

    Find.find(distdir) {|path|
      next unless File.file?(path)

      result += File.size(path) rescue nil
    }

    result
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
