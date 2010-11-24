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

require 'packo/models/repository/package/binary'
require 'packo/models/repository/package/source'
require 'packo/models/repository/package/virtual'

module Packo; module Models; class Repository

class Package
  include DataMapper::Resource

  property :id, Serial

  belongs_to :repo, 'Repository',                                    :unique_index => :a

  has n,   :tags
  property :tags_hashed, String,  :length => 40,  :required => true, :unique_index => :a
  property :name,        String,                  :required => true, :unique_index => :a
  property :version,     String,                  :required => true, :unique_index => :a
  property :slot,        String,  :default => '',                    :unique_index => :a
  property :revision,    Integer, :default => 0

  property :description,  Text, :default => '', :required => false
  property :homepage,     Text, :default => '', :required => false
  property :license,      Text, :default => '', :required => false

  has 1, :binary,  :required => false, :accessor => :private
  has 1, :source,  :required => false, :accessor => :private
  has 1, :virtual, :required => false, :accessor => :private

  def data
    case self.repo.type
      when :binary;  self.binary
      when :source;  self.source
      when :virtual; self.virtual
    end
  end
end

end; end; end
