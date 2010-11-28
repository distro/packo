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

require 'uri'

module Packo; class Package

class Repository
  def self.wrap (model)
    Repository.new(
      :type => model.type,
      :name => model.name,

      :uri  => model.uri,
      :path => model.path,

      :model => model
    )
  end

  def self.parse (text)
    if text.include?('/')
      type, name = text.split('/')

      type = type.to_sym
    else
      type, name = nil, name
    end

    Repository.new(
      :type => type,
      :name => name
    )
  end

  Types = [:binary, :source, :virtual]

  attr_accessor :type, :name, :uri, :path

  attr_reader :model

  def initialize (data)
    self.type = data[:type]
    self.name = data[:name]

    self.uri  = data[:uri]
    self.path = data[:path]

    @model = data[:model]
  end

  def type= (value)
    @type = value.to_sym if value
  end

  def uri= (value)
    @uri = URI.parse(value) if value
  end

  def to_h
    result = {}

    [:type, :name, :uri, :path].each {|name|
      result[name] = self.send(name) unless self.send(name).nil?
    }

    return result
  end
end

end; end
