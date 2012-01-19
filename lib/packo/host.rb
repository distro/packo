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

require 'packo/environment'

module Packo

class Host
	class Part
		def initialize (value)
			assign(value)
		end

		def assign (value)
			@value = self.class.normalize(value)
		end

		def == (value)
			if value.is_a?(Regexp)
				!!@value.to_s.match(value)
			elsif value.is_a?(String)
				@value == self.class.normalize(value)
			else
				super(value)
			end
		end

		alias === ==

		def nil?
			@value.nil?
		end

		def to_s
			@value.to_s
		end
	end

	class Arch < Part
		def self.normalize (value)
			case value
				when 'core2', 'k8', 'amd64' then 'x86_64'
				when 'x86'                  then 'i686'

				when 'i386', 'i486', 'i586', 'i686', 'x86_64' then value

				else raise ArgumentError.new('Architecture not supported')
			end
		end

		def initialize (value = System.env![:ARCH])
			super(value)
		end
	end

	class Vendor < Part
		def self.normalize (value)
			case value
				when 'pc' then value

				else 'unknown'
			end
		end

		def initialize (value = System.env![:VENDOR])
			super(value)
		end
	end

	class Kernel < Part
		def self.normalize (value)
			case value
				when 'windows'          then 'cygwin'
				when 'mac', 'macos'     then 'darwin'
				when /^openbsd(\d\.\d)/ then 'openbsd'

				when 'freebsd', 'openbsd', 'netbsd', 'linux', 'cygwin', 'darwin' then value

				else raise ArgumentError.new('Kernel not supported')
			end
		end

		def initialize (value = System.env![:KERNEL])
			super(value)
		end
	end

	class Misc < Part
		def self.normalize (value)
			case value
				when 'gnu' then value
			end
		end

		def initialize (value = System.env![:MISC])
			super(value)
		end
	end

	def self.parse (text)
		matches = text.match(/^([^-]+)(-([^-]+))?-([^-]+)(-([^-]+))?$/) or return

		Host.new(
			ARCH:   matches[1],
			VENDOR: matches[3],
			KERNEL: matches[4],
			MISC:   matches[6]
		)
	end

	def self.misc (value = System.env![:MISC])
		case value
			when 'gnu'; value
		end
	end

	attr_reader :arch, :vendor, :kernel, :misc

	def initialize (data)
		@arch   = Arch.new(data[:ARCH]) rescue Host.parse(RUBY_PLATFORM).arch
		@vendor = Vendor.new(data[:VENDOR])
		@kernel = Kernel.new(data[:KERNEL]) rescue Host.parse(RUBY_PLATFORM).kernel
		@misc   = Misc.new(data[:MISC])

		if !self.misc && data[:LIBC] == 'glibc' && (self.kernel == 'linux')
			self.misc = 'gnu'
		end

		if self.vendor == 'unknown' && ['x86_64', 'i386', 'i486', 'i586', 'i686'].member?(self.arch)
			self.vendor = 'pc'
		end
	end

	def arch= (value)
		@arch.assign(value)
	end

	def vendor= (value)
		@vendor.assign(value)
	end

	def kernel= (value)
		@kernel.assign(value)
	end

	def misc= (value)
		@misc.assign(value)
	end

	def == (value)
		if value.is_a?(Host)
			self.to_s == value.to_s
		else
			!!self.to_s.match(Regexp.new('^' + Regexp.escape(value.to_s).gsub(/\\\*/, '.*?').gsub(/\\\?/, '.') + '$', 'i'))
		end
	end

	alias === ==

	def posix?
		kernel == 'linux' || kernel == 'windows' || kernel == 'mac'
	end

	def to_s
		"#{arch}#{"-#{vendor}" unless vendor.nil?}-#{kernel}#{"-#{misc}" unless misc.nil?}"
	end
end

end

class String
	refine_method :==, prefix: '__packo' do |value|
		(value.is_a?(Packo::Host) || value.is_a?(Packo::Host::Part)) ? value == self : __send__('__packo_==', value)
	end

	refine_method :===, prefix: '__packo' do |value|
		(value.is_a?(Packo::Host) || value.is_a?(Packo::Host::Part)) ? value === self : __send__('__packo_===', value)
	end
end
