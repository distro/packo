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

module Packo

class Environment < Hash
  @@default = {
    :ARCH     => 'x86',
    :KERNEL   => 'linux',
    :LIBC     => 'glibc',
    :COMPILER => 'gcc',

    :CFLAGS    => '-Os -pipe',
    :CXXFLAGS  => '-Os -pipe',
    :CPPFLAGS  => '',
    :LDFLAGS   => '-Wl,-O1 -Wl,--as-needed',
    :MAKE_JOBS => 1,

    :PROFILE => '/etc/packo.profile',

    :FLAVORS  => 'headers documentation',
    :FEATURES => '',

    :CACHE  => '/var/lib/packo/cache',
    :SELECT => '/var/lib/packo/select',

    :TMP    => '/tmp'
  }

  @@callbacks = {
    :COMPILER => lambda {|value|
      self[:CPP] = 'cpp'
      self[:AS]  = 'as'
      self[:AR]  = 'ar'
      self[:LD]  = 'ld'

      case value
        when 'gcc'
          self[:CC]  = 'gcc'
          self[:CXX] = 'g++'

        when 'clang'
          self[:CC]  = 'clang'
          self[:CXX] = 'clang++'

        else
          raise ArgumentError.new 'I do not know that compiler :<'
      end
    }
  }

  def self.[] (name)
    ENV["PACKO_#{name}"] || ENV[name.to_s] || @@default[name.to_sym]
  end

  def self.[]= (name, value)
    ENV["PACKO_#{name}"] = value.to_s
  end

  def self.each
    @@default.each_key {|name|
      yield name.to_s, Environment[name]
    }
  end

  def self.clone
    result = {}

    Environment.each {|name, value|
      result[name.to_s] = value
    }

    result
  end

  def initialize
    Environment.clone.each {|key, value|
      self[key] = value
    }
  end

  alias __set []=

  def []= (name, value)
    self.instance_exec(value, &@@callbacks[name.to_sym]) if @@callbacks[name.to_sym]

    __set(name, value)
  end

  def sandbox
    old = Hash[ENV]

    self.each {|key, value|
      ENV[key.to_s] = value.to_s
    }

    begin
      error = nil

      yield
    rescue Exception => e
      error = e
    end

    old.each {|key, value|
      ENV[key] = value
    }

    raise error if error
  end
end

end
