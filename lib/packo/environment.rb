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

require 'tempfile'
require 'tmpdir'
require 'pathname'

require 'packo/profile'
require 'packo/flags'

module Packo

class Environment < Hash
	Default = {
		ARCH:     nil,
		KERNEL:   nil,
		LIBC:     'glibc',
		COMPILER: 'gcc',

		CFLAGS:    '-Os -pipe',
		CXXFLAGS:  '-Os -pipe',
		CPPFLAGS:  '',
		LDFLAGS:   '-Wl,-O1 -Wl,--as-needed',
		MAKE_JOBS: 1,

		FLAVOR:   'vanilla',
		FEATURES: '',
		USE:      '',

		PROFILES: '',

		FETCHER: 'wget -c -O "#{output}" "#{source}"',

		NO_COLORS: false,
		DEBUG:     nil,
		VERBOSE:   false,
		SECURE:    true,

		TMP: "#{Dir.tmpdir}/packo-#{ENV['USER'] || Process.euid}"
	}

	if Process.euid == 0 && ENV['USER'] == 'root'
		Default.merge!(
			MAIN_PATH:    '/var/lib/packo',
			CONFIG_PATH:  '/etc/packo',
			INSTALL_PATH: '/',
			FETCH_PATH:   '/var/tmp/packo',

			DATABASE: 'sqlite:///var/lib/packo/db',
		)
	else
		Default.merge!(
			MAIN_PATH:    "#{ENV['HOME']}/.packo",
			CONFIG_PATH:  "#{ENV['HOME']}/.packo",
			INSTALL_PATH: "#{ENV['HOME']}/.packo/disk",
			FETCH_PATH:   "#{ENV['HOME']}/.packo/fetch",

			DATABASE: "sqlite://#{ENV['HOME']}/.packo/db",
		)
	end

	Callbacks = {
		COMPILER: lambda {|value|
			self[:CPP]    = 'cpp'
			self[:AS]     = 'as'
			self[:AR]     = 'ar'
			self[:LD]     = 'ld'
			self[:RANLIB] = 'ranlib'

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

	def self.[] (name, nodefault = false)
		value = ENV["PACKO_#{name}"] || ENV[name.to_s] || (nodefault ? nil : Default[name.to_sym]) or return

		return value unless value.is_a?(String)

		return nil if value.strip.empty?

		return case value.strip
			when 'false';   false
			when 'true';    true
			else;           value
		end
	end

	def self.[]= (name, specific = true, value)
		ENV[specific ? "PACKO_#{name}" : "#{name}"] = value.to_s rescue ''
	end

	def self.each (limit = true)
		variables = (Default.keys + (ENV.map {|(key, value)|
			if limit
				key.sub(/^PACKO_/, '').to_sym if key.start_with?('PACKO_')
			else
				key.start_with?('PACKO_') ?
					key.sub(/^PACKO_/, '').to_sym :
					key.to_sym
			end
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

	attr_reader :package, :profiles

	def initialize (package = nil, noenv = false)
		@package  = package
		@profiles = []

		@profiles << Profile.path(Environment[:CONFIG_PATH])
		@profiles << Profile.path("#{ENV['HOME']}/.packo")
		@profiles << Profile.path('/var/lib/packo')

		Environment[:PROFILES].split(/\s*;\s*/).each {|profile|
			@profiles << Profile.path(profile)
		} if Environment[:PROFILES]

		if File.readable?("#{ENV['HOME']}/.packo/profiles")
			files = File.read("#{ENV['HOME']}/.packo/profiles").split("\n")
		elsif File.readable?('/etc/packo/profiles')
			files << File.read('/etc/packo/profiles').split("\n")
		end

		files.each {|profile|
			@profiles << Profile.path(profile)
		} if files

		@profiles.compact!

		apply!(noenv)

		yield self if block_given?
	end

	def apply! (noenv = false)
		clear

		@profiles.each {|profile|
			profile.apply!(self, @package)
		}

		if noenv
			Default.each {|key, value|
				self[key] = value unless self[key]
			}
		else
			Environment.each(false) {|key, value|
				next if value.nil?

				# NOTE: This is an array, not a call to self.[]
				if [:FEATURES].member?(key)
					(self[key] ||= '') << " #{value}"
				else
					self[key] = value unless self[key] && value == Default[key] && !Environment[key, true]
				end
			}
		end

		each {|key, value|
			if key.to_s.end_with?('FLAGS')
				self[key] = Flags.parse(value.to_s)
			elsif key.to_s.end_with?('PATH')
				self[key] = Path.new(value.to_s)
			end
		}
	end

	def [] (name)
		super(name.to_sym)
	end

	def []= (name, value)
		instance_exec value, &Callbacks[name.to_sym] if Callbacks[name.to_sym]

		if name.to_s.end_with?('FLAGS')
			value = Flags.parse(value.to_s)
		elsif name.to_s.end_with?('PATH')
			value = Path.new(value.to_s)
		end

		super(name.to_sym, value)
	end

	def sandbox (changes = {}, &block)
		Environment.sandbox(merge({
			ARCH: Host.new(self).arch
		}.merge(changes)), &block)
	end
end

end
