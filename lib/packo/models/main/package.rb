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

require 'packo/binary/models/main/package/dependency'
require 'packo/binary/models/main/package/content'

module Packo; module Binary; module Models; module Main

class Package
  include DataMapper::Resource

  property :id, Serial

  property :repo, String

  property :categories, String, :length => 255, :required => true, :unique_index => :a
  property :name,       String,                 :required => true, :unique_index => :a
  property :version,    String,                 :required => true
  property :slot,       String,  :default => '',                   :unique_index => :a
  property :revision,   Integer, :default => 0

  property :flavors,  Text, :default => ''
  property :features, Text, :default => ''

  property :manual,  Boolean, :default => false
  property :runtime, Boolean, :default => true  # Installed as build or runtime dependency

  has n, :dependencies
  has n, :contents
end

end; end; end; end
