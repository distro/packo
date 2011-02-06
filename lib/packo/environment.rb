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
    :ARCH     => nil,
    :KERNEL   => nil,
    :LIBC     => nil,
    :COMPILER => nil,

    :CFLAGS    => '-Os -pipe',
    :CXXFLAGS  => '-Os -pipe',
    :CPPFLAGS  => '',
    :LDFLAGS   => '-Wl,-O1 -Wl,--as-needed',
    :MAKE_JOBS => 1,

    :FLAVOR   => 'headers documentation',
    :FEATURES => '',

    :PROFILE => '/etc/packo.profile',

    :CONFIG_FILE    => '/etc/packo.conf',
    :CONFIG_PATH    => '/etc/packo',
    :CONFIG_MODULES => '/etc/packo/modules',

    :DATABASE => 'sqlite:///var/lib/packo/db',

    :REPOSITORIES => '/var/lib/packo/repositories',
    :SELECTORS    => '/var/lib/packo/selectors',

    :FETCHER => 'wget -c -O "#{output}" "#{source}"',

    :NO_COLORS => false,
    :DEBUG     => nil,
    :VERBOSE   => false,
    :SECURE    => true,

    :TMP => '/var/tmp/packo'
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
          raise ArgumentError.new 'I do not know that compiler :<' if value
      end
    }
  }

  def self.[] (name, nodefault=false)
    value = ENV["PACKO_#{name}"] || ENV[name.to_s] || (nodefault ? nil : @@default[name.to_sym]) or return

    return value unless value.is_a?(String)

    case value
      when value.strip.empty?; nil
      when value == 'false';   false
      when value == 'true';    true
      else;                    value
    end
  end

  def self.[]= (name, value)
    ENV["PACKO_#{name}"] = value.to_s rescue ''
  end

  def self.each
    variables = (@@default.keys + (ENV.map {|(key, value)|
      key.sub(/^PACKO_/, '').to_sym if key.match(/^PACKO_/)
    }.compact)).uniq

    if variables.member?(:FLAVORS)
      variables.delete(:FLAVORS)
      variables << :FLAVOR

      Environment[:FLAVOR] = Environment[:FLAVORS]
    end

    variables.each {|name|
      yield name, Environment[name]
    }
  end

  def self.clone
    result = {}

    Environment.each {|name, value|
      result[name.to_s] = value
    }

    result
  end

  def self.sandbox (box)
    old = Hash[ENV]

    box.each {|key, value|
      ENV[key.to_s] = value.to_s
    }

    begin
      result = yield
    rescue Exception => e
      result = e
    end

    box.each {|key, value|
      ENV.delete(key.to_s)
    }

    old.each {|key, value|
      ENV[key] = value
    }

    if result.is_a?(Exception)
      raise result
    else
      return result
    end
  end

  attr_reader :package

  def initialize (package=nil, noenv=false)
    @package = package

    mod = ::Module.new

    files = [Environment[:CONFIG_FILE]] + Environment[:PROFILE].split(/\s*;\s*/).map {|profile|
      "#{profile}/config"
    }

    if File.readable?("#{ENV['HOME']}/.packo.profiles")
      files << File.read("#{ENV['HOME']}/.packo.profiles").split("\n")
    elsif File.readable?('/etc/packo.profiles')
      files << File.read('/etc/packo.profiles').split("\n")
    end

    files.flatten.uniq.each {|file|
      begin
        suppress_warnings {
          mod.module_eval File.read(file)
        } if File.readable?(file)
      rescue Exception => e
        Packo.debug e
      end
    }

    if package && package.respond_to?(:on)
      (Environment[:PROFILE].split(/\s*;\s*/).map {|profile|
        "#{profile}/config"
      } + [Environment[:CONFIG_MODULES]]).each {|path|
        Dir.glob("#{path}/*.rb").each {|file|
          Packo.load file, binding
        }
      }
    end

    mod.constants.each {|const|
      self[const] = mod.const_get const
    }

    Environment.each {|key, value|
      next if value.nil?

      # This is an array, not a call to self.[]
      if [:FEATURES].member?(key)
        if self[key].is_a?(String)
          self[key] << " #{value}"
        else
          self[key] = value
        end
      else
        self[key] = value unless self[key] && value == @@default[key] && !Environment[key, true]
      end
    } unless noenv

    yield self if block_given?
  end

  alias __get []

  def [] (name)
    __get(name.to_sym)
  end

  alias __set []=

  def []= (name, value)
    self.instance_exec(value, &@@callbacks[name.to_sym]) if @@callbacks[name.to_sym]

    __set(name.to_sym, value)
  end

  def sandbox (changes={}, &block)
    Environment.sandbox(self.merge({
      :ARCH => Host.new(self).arch
    }.merge(changes)), &block)
  end
end

end
