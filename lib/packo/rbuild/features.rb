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

require 'packo/package/features'

require 'packo/rbuild/feature'

module Packo; module RBuild

class Features < Packo::Package::Features
	Default = Class.new(Hash) {
		def define (name, &block)
			(self[name.to_sym] ||= []) << block
		end
	}.new

	attr_reader :package

	def initialize (package, values={})
		super(values)

		@package = package

		yield self if block_given?
	end

	def set (name, &block)
		define name
		@values[name.to_sym] = Feature.new(@package, name, &block)
	end

	def get (name)
		define name
		@values[name.to_sym] ||= Feature.new(@package, name, false)
	end

	def delete (name)
		undefine name
		@values.delete(name.to_sym)
	end

	def define (name)
		return if respond_to?(name)

		define_singleton_method name           do get(name) end
		define_singleton_method "#{name}?"     do get(name).enabled? end
		define_singleton_method "not_#{name}!" do get(name).disable! end
		define_singleton_method "#{name}!"     do get(name).enable! end
	end

	def undefine (name)
		[name, "#{name}?", "not_#{name}!", "#{name}!"].each {|name|
			class << self; self; end.undef_method name
		}
	end

	def needs (expression = nil)
		expression ? @needs = expression : @needs
	end

	def dsl (&block)
		Class.new(BasicObject) {
			def initialize (features, &block)
				@features = features

				instance_eval &block
			end

			def method_missing (id, *args, &block)
				return @features.__send__ id, *args, &block if @features.respond_to?(id)

				super unless block

				@features.get(id).do(&block)
			end
		}.new(self, &block)
	end
end

end; end
