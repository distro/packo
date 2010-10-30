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
          @with[name.to_s] = !value
        else
          @with[name.to_s] = false
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
          else;       result += "--enable-#{name}=#{value} "
        end
      }

      @with.each {|name, value|
        case value
          when true;  result += "--with-#{name} "
          when false; result += "--without-#{name} "
          else;       result += "--with-#{name}=#{value} "
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
  end

  def configure
    @configuration = Configuration.new(self)

    FileUtils.mkpath "#{package.distdir}/usr"

    @configuration.set 'prefix',        "#{package.distdir}/usr"
    @configuration.set 'mandir',        "#{package.distdir}/usr/share/man"
    @configuration.set 'infodir',       "#{package.distdir}/usr/share/info"
    @configuration.set 'datadir',       "#{package.distdir}/usr/share"
    @configuration.set 'sysconfdir',    "#{package.distdir}/etc"
    @configuration.set 'localstatedir', "#{package.distdir}/var/lib"
    @configuration.set 'libdir',        "#{package.distdir}/usr/lib"

    if (error = package.stages.call(:configure, @configuration).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end

    do_configure
  end

  def do_configure (conf=nil, fire=true)
    if !File.exists? 'configure'
      Packo.sh 'autoconf'
    end

    if !File.exists? 'Makefile'
      Packo.sh "./configure #{conf || @configuration}"
    end

    package.stages.call(:configured, conf || @configuration) if fire
  end

  def compile
    if (error = package.stages.call(:compile, @configuration).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end

    do_compile
  end

  def do_compile (conf=nil, fire=true)
    Packo.sh 'make'

    package.stages.call(:compiled, conf || @configuration) if fire
  end

  def install
    if (error = package.stages.call(:install, @configuration).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end

    do_install
  end

  def do_install (conf=nil, fire=true)
    Packo.sh 'make install'

    package.stages.call(:installed, conf || @configuration) if fire
  end
end

end

end

end
