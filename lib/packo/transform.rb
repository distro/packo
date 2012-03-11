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

module Packo

class Transform
	def self.open (path)
		transform = new

		if (tmp = File.read(path, encoding: 'utf-8').split(/^__END__$/, 2)).length > 1
			transform.filesystem.parse(tmp.last.lstrip)
		end

		transform.instance_eval(tmp.first)
		transform
	end

	attr_reader :filesystem

	alias fs filesystem

	def initialize
		@blocks     = {}
		@filesystem = FFFS::FileSystem.new
	end

	def apply_to (what)
		if defined?(RBuild::Package) && what.is_a?(RBuild::Package)
			what.apply(self, &@blocks[:build])
		end
	end

	[:build, :install].each {|name|
		define_method name do |&block|
			@blocks[name] = block
		end
	}
end

end
