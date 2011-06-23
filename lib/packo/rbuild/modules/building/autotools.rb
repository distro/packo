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

module Packo; module RBuild; module Modules; module Building

class Autotools < Module
  class Configuration
    attr_accessor :path
    attr_reader   :package

    def initialize (package=nil)
      @package = package

      @enable = {}
      @with   = {}
      @other  = {}

      @path = './configure'
    end

    def clear
      @enable.clear
      @with.clear
      @other.clear
    end

    def with (name, value=nil)
      [name].flatten.each {|name|
        if value === true || value === false
          @with[name.to_s] = value
        else
          @with[name.to_s] = value ? value.to_s : true
        end
      }
    end

    def without (name, value=nil)
      [name].flatten.each {|name|
        if value === true || value === false
          @with[name.to_s] = !value
        else
          @with[name.to_s] = false
        end
      }
    end

    def enable (name, value=nil)
      [name].flatten.each {|name|
        if value === true || value === false
          @enable[name.to_s] = value
        else
          @enable[name.to_s] = value ? value.to_s : true
        end
      }
    end

    def disable (name, value=nil)
      [name].flatten.each {|name|
        if value === true || value === false
          @enable[name.to_s] = !value
        else
          @enable[name.to_s] = false
        end
      }
    end

    def set (name, value)
      @other[name.to_s] = value.to_s
    end

    def get (name)
      @other[name.to_s]
    end

    def delete (from, *names)
      names.flatten.each {|name|
        case from.to_sym
          when :with;   @with.delete(name.to_s)
          when :enable; @enable.delete(name.to_s)
          when :other;  @other.delete(name.to_s)
        end
      }
    end

    def execute
      @package.env.sandbox {
        Packo.sh "#{self.path} #{self}"
      }
    end

    def to_s
      result = ''

      @enable.each {|name, value|
        case value
          when true;  result += "--enable-#{name.shellescape} "
          when false; result += "--disable-#{name.shellescape} "
          else;       result += "--enable-#{name.shellescape}=#{value.shellescape} "
        end
      }

      @with.each {|name, value|
        case value
          when true;  result += "--with-#{name.shellescape} "
          when false; result += "--without-#{name.shellescape} "
          else;       result += "--with-#{name.shellescape}=#{value.shellescape} "
        end
      }

      @other.each {|name, value|
        result += "--#{name.shellescape}=#{value.shellescape} "
      }

      return result
    end
  end

  def initialize (package)
    super(package)

    package.avoid package.stages.owner_of(:compile)

    package.stages.add :configure, self.method(:configure), after: :fetch
    package.stages.add :compile,   self.method(:compile),   after: :configure
    package.stages.add :install,   self.method(:install),   after: :compile

    if package.type == 'library'
      package.filesystem.post << FFFS::File.new('ld-config-update.sh', %{
        #! /bin/sh
        ldconfig
      })
    end

    before :pack do
      slot = package.slot.to_s

      if package.host != package.target
        slot << '-' unless slot.empty?
        slot << package.target.to_s
      end

      package.slot = slot
    end

    if package.env[:CROSS]
      package.host = Host.new(System.env!)
    else
      package.host = Host.new(package.environment)
    end

    if package.env[:TARGET]
      package.target = Host.parse(package.env[:TARGET]) 
    else
      package.target = Host.new(package.environment) 
    end

    package.environment[:CHOST]   = package.host.to_s
    package.environment[:CTARGET] = package.target.to_s

    package.autotools = Class.new(Module::Helper) {
      attr_accessor :m4

      def initialize (package)
        super(package)

        @versions = {}
        @enabled  = true
        @forced   = false
      end

      def enabled?;   @enabled         end
      def disabled?; !@enabled         end
      def enable!;    @enabled = true  end
      def disable!;   @enabled = false end

      def forced?; @forced        end
      def force!;  @forced = true end

      def configure (conf)
        conf.execute
      end

      def autogen
        self.autoreconf '-i'
        self.autoheader
        self.automake
      end

      def autoreconf (*args)
        version = args.last.is_a?(Numeric) ? args.pop : nil

        package.environment.sandbox {
          Packo.sh "autoreconf#{"-#{version}" if version}", *args
        }
      end

      def aclocal (*args)
        version = args.last.is_a?(Numeric) ? args.pop : @versions[:aclocal]

        args.insert(0, ['-I', @m4]) if @m4

        package.environment.sandbox {
          Packo.sh "aclocal#{"-#{version}" if version}", *args
        }
      end

      def autoconf (*args)
        version = args.last.is_a?(Numeric) ? args.pop : @versions[:autoconf]

        package.environment.sandbox {
          Packo.sh "autoconf#{"-#{version}" if version}", *args
        }
      end

      def autoheader (*args)
        version = args.last.is_a?(Numeric) ? args.pop : @versions[:autoheader]

        package.environment.sandbox {
          Packo.sh "autoheader#{"-#{version}" if version}", *args
        }
      end

      def automake (*args)
        version = args.last.is_a?(Numeric) ? args.pop : @versions[:automake]

        package.environment.sandbox {
          Packo.sh "automake#{"-#{version}" if version}", *args
        }
      end

      def autoupdate (*args)
        version = args.last.is_a?(Numeric) ? args.pop : @versions[:autoupdate]

        package.environment.sandbox {
          Packo.sh "autoupdate#{"-#{version}" if version}", *args
        }
      end

      def make (*args)
        package.environment.sandbox {
          Packo.sh 'make', *args
        }
      end

      def install (path=nil, *args)
        package.environment.sandbox(DESTDIR: path || package.distdir) {
          puts ENV['DESTDIR']

          self.make "DESTDIR=#{path || package.distdir}", 'install', *args
        }
      end

      def version (name, slot=nil)
        slot ? @versions[name.to_sym] = slot : @versions[name.to_sym]
      end
    }.new(package)
  end

  def finalize
    package.stages.delete :configure, self.method(:configure)
    package.stages.delete :compile,   self.method(:compile)
    package.stages.delete :install,   self.method(:install)

    package.autotools = nil
  end

  def configure
    @configuration = Configuration.new(package)

    @configuration.set 'prefix',         Path.clean(System.env[:INSTALL_PATH] + '/usr')
    @configuration.set 'sysconfdir',     Path.clean(System.env[:INSTALL_PATH] + '/etc')
    @configuration.set 'sharedstatedir', Path.clean(System.env[:INSTALL_PATH] + '/com')
    @configuration.set 'localstatedir',  Path.clean(System.env[:INSTALL_PATH] + '/var')

    @configuration.set 'host',   package.host
    @configuration.set 'build',  package.host

    if package.host != package.target
      @configuration.set 'target', package.target
    end

    package.callbacks(:configure).do(@configuration) {
      next if package.autotools.disabled?

      if !File.exists? @configuration.path
        Do.cd(File.dirname(@configuration.path)) {
          package.autotools.autogen
        }
      end

      if !File.exists?('Makefile') || package.autotools.forced?
        package.autotools.configure(@configuration)
      end
    }
  end

  def compile
    package.callbacks(:compile).do(@configuration) {
      next if package.autotools.disabled?

      package.autotools.make "-j#{package.env[:MAKE_JOBS]}"
    }
  end

  def install
    package.callbacks(:install).do(@configuration) {
      next if package.autotools.disabled?

      package.autotools.install
    }
  end
end

end; end; end; end
