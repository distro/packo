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

class Repository
	Types = [:binary, :source, :virtual]

	def self.parse (text)
		if text.include?('/')
			type, name = text.split('/')

			type = type.to_sym
		else
			type, name = nil, name
		end

		Repository.new(
			type: type,
			name: name
		)
	end

	def self.wrap (model)
		Repository.const_get(model.type.to_sym.capitalize).new(
			type: model.type.to_sym,
			name: model.name,

			location: model.location,
			path:     model.path,

			model: model
		)
	end

	attr_accessor :type, :name, :location, :path

	attr_reader :model

	def initialize (data)
		self.type = data[:type]
		self.name = data[:name]

		self.location = data[:location]
		self.path     = data[:path]

		@model = data[:model]
	end

	def type= (value)
		@type = value.to_sym if value
	end

	def location= (value)
		@location = value.is_a?(Packo::Location) ? value : Packo::Location[value] if value
	end

	def packages (*args)
		Enumerator.new(self, :each_package, *args)
	end

	def dependencies (package, *args)
		Enumerator.new(self, :each_dependency, package, *args)
	end

	def has? (package)
		false
	end

	def to_hash
		result = {}

		[:type, :name, :location, :path].each {|name|
			result[name] = self.send(name) unless self.send(name).nil?
		}

		return result
	end

	def to_s
		"#{self.type[/(::)?([^:]+)$/, 2].downcase}/#{self.name}"
	end
end

end

require 'packo/repository/binary'
require 'packo/repository/source'
require 'packo/repository/virtual'
