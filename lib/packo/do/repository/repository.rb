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

module Packo; class Do; class Repository; module Helpers

module Repository
	extend Forwardable

	attr_reader    :model
	def_delegators :model, :type, :name, :location, :path

	def self.wrap (model)
		raise ArgumentError.new('You passed a nil model.') unless model

		model.save

		case model.type
			when :binary  then Helpers::Binary.new(model)
			when :source  then Helpers::Source.new(model)
			when :virtual then Helpers::Virtual.new(model)
		end
	end
end

require 'packo/do/repository/binary'
require 'packo/do/repository/source'
require 'packo/do/repository/virtual'

end; end; end; end
