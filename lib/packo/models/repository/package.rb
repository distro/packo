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

require 'packo/models/tag'

module Packo; module Models; class Repository

class Package
	include DataMapper::Resource

	def self.to_sym
		name.split('::').last.downcase.to_sym
	end

	property :id, Serial

	belongs_to :repo, 'Repository'
	property   :type, Discriminator
	has n,     :tags, through: Resource, constraint: :destroy

	property :repository_id, Integer,                               unique_index: :a
	property :tags_hashed,   String,  length: 40,   required: true, unique_index: :a
	property :name,          String,  length: 255,  required: true, unique_index: :a
	property :version,       Version,               required: true, unique_index: :a
	property :slot,          String,  default: '',                  unique_index: :a
	property :revision,      Integer, default: 0

	property :description,  Text
	property :homepage,     Text
	property :license,      Text

	property :maintainer, String
end

end; end; end

require 'packo/models/repository/package/binary'
require 'packo/models/repository/package/source'
require 'packo/models/repository/package/virtual'
