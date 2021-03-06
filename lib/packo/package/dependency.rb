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

module Packo; class Package

class Dependency < Package
	def self.parse (text, type=nil)
		return text if text.is_a?(Dependency)

		text = text.dup

		if text.end_with? '!!'
			text[-2, 2] = ''

			type ||= :runtime
		elsif text.end_with? '!'
			text[-1] = ''

			type ||= :build
		elsif matches = text.match(/#(.*?)$/)
			text.sub!(/#.*?$/, '')

			type ||= matches[1]
		else
			type ||= :build_and_runtime
		end

		if matches = text.match(/^([<>~]?=?)/)
			validity = ((matches[1] && !matches[1].empty?) ? matches[1] : nil)
			text.sub!(/^([<>~]?=?)/, '')
		else
			validity = nil
		end

		parsed = Packo::Package.parse(text, only_parse: true)

		new(parsed.to_hash, validity, type)
	end

	attr_reader :type, :validity

	def initialize (data, validity=nil, type=:build_and_runtime)
		super(data, only_parse: true)

		@validity = validity
		@type     = type
	end
	
	def method_missing (id, *args, &block)
		if id.to_s.end_with?('?')
			@type == id.to_s[0 .. -2].to_sym
		else
			super
		end
	end

	def in? (package)
		return false if package.name != name || package.tags != tags

		return true if !version

		case validity
			when '~', '~=' then !!package.version.to_s.match(/^#{Regexp.escape(version.to_s)}/)
			when '>'       then package.version >  version
			when '>='      then package.version >= version
			when '<'       then package.version <  version
			when '<='      then package.version <= version
			else                package.version == version
		end
	end

	def to_s (type=:normal)
		case type
			when :short
				"#{validity}#{tags}/#{name}#{"-#{version}" if version}#{"%#{slot}" if slot}##{type}"

			else
				features = features.to_a.sort {|a, b|
					if a.enabled? && b.enabled?     ;  0
					elsif a.enabled? && !b.enabled? ; -1
					else                            ;  1
					end
				}.map {|feature|
					(feature.enabled? ? '' : '-') + feature.name.to_s
				}.join(',')

				flavor = flavor.to_a.map {|f|
					f.name.to_s
				}.sort

				"#{validity}#{tags}/#{name}#{"-#{version}" if version}#{"%#{slot}" if slot}##{type}#{"[#{features}]" if !features.empty?}#{"{#{flavor}}" if !flavor.empty?}"
		end
	end
end

end; end
