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

require 'packo/models/installed_package/dependency'
require 'packo/models/installed_package/content'

module Packo; module Models

class InstalledPackage
  include DataMapper::Resource

  property :id, Serial

  property :repo, String

  has n,   :tags
  property :tags_hashed, String, :length => 40,  :required => true, :unique_index => :a # hashed tags
  property :name,        String,                 :required => true, :unique_index => :a
  property :version,     String,                 :required => true
  property :slot,        String,  :default => '',                   :unique_index => :a
  property :revision,    Integer, :default => 0

  property :flavors,  Text, :default => ''
  property :features, Text, :default => ''

  property :manual,  Boolean, :default => false
  property :runtime, Boolean, :default => true  # Installed as build or runtime dependency

  has n, :dependencies
  has n, :contents

  def self.search (expression, exact=false)
    if matches = expression.match(/^([<>]?=?)/)
      validity = ((matches[1] && !matches[1].empty?) ? matches[1] : nil)
      expression = expression.sub(/^([<>]?=?)/, '')

      validity = nil if validity == '='
    else
      validity = nil
    end

    package = Packo::Package.parse(expression)

    conditions = {}

    op = exact ? :eql : :like

    conditions[Query::Operator.new(:name, op)]       = package.name if package.name
    conditions[Query::Operator.new(:version, op)]    = package.version if package.version
    conditions[Query::Operator.new(:slot, op)]       = package.slot if package.slot

    result = InstalledPackage.all(conditions)

    result.delete_if {|pkg|
      !Tagging::Tagged.all(:type => :installed, :package => pkg.id).find {|tagged|
        pkg.tags.member? tagged.tag.name
      }
    }

    return result if !validity

    result.select {|pkg|
      case validity
        when '>';  Versionomy.parse(pkg['version']) >  package.version
        when '>='; Versionomy.parse(pkg['version']) >= package.version
        when '<';  Versionomy.parse(pkg['version']) <  package.version
        when '<='; Versionomy.parse(pkg['version']) <= package.version
      end
    }
  end
end

end; end
