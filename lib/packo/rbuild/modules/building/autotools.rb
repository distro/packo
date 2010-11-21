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

require 'packo/module'

module Packo

module Modules

module Building

class Autotools < Module
  class Configuration
    attr_reader :module

    def initialize (mod)
      @module = mod

      @enable = {}
      @with   = {}
      @other  = {}
    end

    def with (name, value=nil)
      [name].flatten.each {|name|
        if value === true || value === false
          @with[name.to_s] = value
        else
          @with[name.to_s] = value || true
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
          @enable[name.to_s] = value || true
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

    def to_s
      result = ''

      @enable.each {|name, value|
        case value
          when true;  result += "--enable-#{name} "
          when false; result += "--disable-#{name} "
          else;       result += "--enable-#{name}='#{value}' "
        end
      }

      @with.each {|name, value|
        case value
          when true;  result += "--with-#{name} "
          when false; result += "--without-#{name} "
          else;       result += "--with-#{name}='#{value}' "
        end
      }

      @other.each {|name, value|
        result += "--#{name}='#{value}' "
      }

      return result
    end
  end

  def initialize (package)
    super(package)

    package.stages.add :configure, self.method(:configure), :after => :fetch
    package.stages.add :compile,   self.method(:compile),   :after => :configure
    package.stages.add :install,   self.method(:install),   :after => :compile

    if package.type == 'library'
      package.post 'ld-config-update.sh', %{
        #! /bin/sh
        ldconfig
      }
    end

    package.on :initialize do |package|
      package.autotools = Class.new(Module::Helper) {
        def initialize (package)
          super(package)

          @versions = {}
        end

        def configure (conf)
          package.environment.sandbox {
            Packo.sh "./configure #{conf}"
          }
        end

        def autogen
          self.autoreconf
          self.autoheader
          self.automake
        end

        def autoreconf (version=nil)
          package.environment.sandbox {
            Packo.sh 'aclocal'
            Packo.sh "autoreconf#{"-#{version}" if version}"
          }
        end

        def autoconf (version=nil)
          package.environment.sandbox {
            Packo.sh "autoconf#{"-#{version}" if version}"
          }
        end

        def autoheader (version=nil)
          package.environment.sandbox {
            Packo.sh "autoheader#{"-#{version}" if version}"
          }
        end

        def automake (version=nil)
          package.environment.sandbox {
            Packo.sh "automake#{"-#{version}" if version}"
          }
        end

        def autoupdate (version=nil)
          package.environment.sandbox {
            Packo.sh "autoupdate#{"-#{version}" if version}"
          }
        end

        def make (*args)
          package.environment.sandbox {
            Packo.sh 'make', *args
          }
        end

        def install (path=nil)
          package.environment.sandbox {
            self.make "DESTDIR=#{path || package.distdir}", 'install'
          }
        end

        def version (name, slot=nil)
          slot ? @versions[name.to_sym] = slot : @versions[name.to_sym]
        end
      }.new(package)
    end
  end

  def configure
    @configuration = Configuration.new(self)

    FileUtils.mkpath "#{package.distdir}/usr"

    @configuration.set 'prefix',         '/usr'
    @configuration.set 'sysconfdir',     '/etc'
    @configuration.set 'sharedstatedir', '/com'
    @configuration.set 'localstatedir',  '/var'

    if (error = package.stages.call(:configure, @configuration).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end

    if !File.exists? 'configure'
      package.autotools.autogen
    end

    if !File.exists? 'Makefile'
      package.autotools.configure(@configuration)
    end

    package.stages.call(:configured, @configuration)
  end

  def compile
    if (error = package.stages.call(:compile, @configuration).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end

    package.autotools.make "-j#{package.environment['MAKE_JOBS']}"

    package.stages.call(:compiled, @configuration)
  end

  def install
    if (error = package.stages.call(:install, @configuration).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end

    package.autotools.install

    package.stages.call(:installed, @configuration)
  end
end

end

end

end
