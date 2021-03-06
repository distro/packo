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

require 'packo/callbackable'
require 'packo/package/feature'

module Packo; module RBuild

class Feature < Packo::Package::Feature
	Callbackable.instance_methods.each {|meth|
		define_method meth do |*args, &block|
			package.__send__ meth, *args, &block
		end
	}

	attr_reader :package, :block, :dependencies

	def initialize (package, name, value = false, &block)
		super(name, value)

		@package      = package
		@dependencies = []

		if Features::Default[to_sym]
			Features::Default[to_sym].each {|feature|
				instance_eval &feature
			}
		end

		self.do(&block)
	end

	def do (&block)
		instance_eval &block if block

		self
	end

	def needs (expression = nil)
		expression ? @needs = expression : @needs
	end

	def method_missing (id, *args, &block)
		@package.send id, *args, &block
	end
end

end; end
