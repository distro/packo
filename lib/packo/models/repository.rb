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

require 'packo/models/repository/package'

require 'packo/models/repository/binary'
require 'packo/models/repository/source'
require 'packo/models/repository/virtual'

require 'ostruct'

module Packo; module Models

class Repository
  include DataMapper::Resource

  Types = [:binary, :source, :virtual]

  attr_accessor :data

  property :id, Serial

  property :name, String,                           :required => true
  property :type, Enum[:binary, :source, :virtual], :required => true

  property :uri,  Text, :required => true
  property :path, Text, :required => true

  has n, :packages

  after :create do |repo|
    case repo.type
      when :binary;  repo.data = Binary.create(:repo => repo)
      when :source;  repo.data = Source.create(:repo => repo)
      when :virtual; repo.data = Virtual.create(:repo => repo)
    end
  end

  after :destroy do |repo|
    repo.data.destroy! if repo.data
  end

  def self.parse (text)
    if text.include?('/')
      type, name = text.split('/')

      type = type.to_sym
    else
      type, name = nil, name
    end

    OpenStruct.new(
      :type => type,
      :name => name
    )
  end

  def search (expression, exact=false)
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

    conditions[Query::Operator.new(:name, op)]    = package.name if package.name
    conditions[Query::Operator.new(:version, op)] = package.version if package.version
    conditions[Query::Operator.new(:slot, op)]    = package.slot if package.slot

    result = packages.all(conditions)

    result.delete_if {|pkg|
      !Tagging::Tagged.all(:package => pkg.id).find {|tagged|
        pkg.tags.member? tagged.tag.name
      }
    }

    return result if !validity

    result.select {|pkg|
      case validity
        when '>';  pkg.version >  package.version
        when '>='; pkg.version >= package.version
        when '<';  pkg.version <  package.version
        when '<='; pkg.version <= package.version
      end
    }
  end
end

end; end
