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

require 'packo/package/repository'
require 'packo/package/tags'
require 'packo/package/flavor'
require 'packo/package/features'

module Packo

class Package
  def self.parse (text, type=:standard)
    data = {}

    case type
      when :standard
        matches = text.match(/^(.*?)(\[(.*?)\])?(\{(.*?)\})?$/)
    
        data[:features] = Hash[(matches[3] || '').split(/\s*,\s*/).map {|feature|
          if feature[0] == '-'
            [feature[1, feature.length], false]
          else
            [(feature[0] == '+' ? feature[1, feature.length] : feature), true]
          end
        }]
    
        data[:flavor] = (matches[5] || '').split(/\s*,\s*/)
    
        matches = matches[1].match(/^(.*?)(-(\d.*))?$/)
    
        data[:tags] = matches[1].split('/')
    
        if matches[1][matches[1].length - 1] != '/'
          data[:name] = data[:tags].pop
        end
    
        if matches[3]
          matches = matches[3].match(/^(.*?)(%(.*)$)?$/)
    
          data[:version] = matches[1]
          data[:slot]    = matches[3]
        end
    end

    Package.new(data)
  end

  def self.wrap (model)
    Package.new(
      :tags     => model.tags.map {|t| t.name},
      :name     => model.name,
      :version  => model.version,
      :slot     => model.slot,
      :revision => model.revision,

      :features => (case model.repo.type
        when :binary; model.data.features
        when :source; model.data.features.map {|f| f.name}.join(' ')
      end),

      :description => model.description,
      :homepage    => model.homepage,
      :license     => model.license,

      :repository => Repository.wrap(model.repo),
      :model      => model
    )
  end

  attr_accessor :tags, :name, :version, :slot, :revision,
                :repository,
                :flavor, :features,
                :description, :homepage, :license

  attr_reader :model

  def initialize (data)
    self.tags       = data[:tags]
    self.name       = data[:name]
    self.version    = data[:version]
    self.slot       = data[:slot]
    self.revision   = data[:revision]

    self.repository = data[:repository]

    self.flavor   = data[:flavor]
    self.features = data[:features]

    self.description = data[:description]
    self.homepage    = data[:homepage]
    self.license     = data[:license]

    @model = data[:model]
  end

  def tags= (value)
    @tags = ((value.is_a?(Tags)) ? value : Tags.parse(value)) if value
  end

  def version= (value)
    @version = ((value.is_a?(Versionomy::Value)) ? value : Versionomy.parse(value.to_s)) if value
  end

  def slot= (value)
    @slot = ((value.is_a?(Versionomy::Value)) ? value : Versionomy.parse(value.to_s)) if value
  end

  def revision= (value)
    @revision = value.to_i rescue 0
  end

  def flavor= (value)
    @flavor = ((value.is_a?(Flavor)) ? value : Flavor.parse(value.to_s)) if value
  end

  def features= (value)
    @features = ((value.is_a?(Features)) ? value : Features.parse(value.to_s)) if value
  end

  def == (package)
    self.name == package.name &&
    self.tags == (package.is_a?(Models::Repository::Package) ? Package.wrap(package).tags : package.tags)
  end

  def === (package)
    self.name     == package.name &&
    self.tags     == (package.is_a?(Models::Repository::Package) ? Package.wrap(package).tags : package.tags) &&
    self.version  == package.version &&
    self.slot     == package.slot &&
    self.revision == package.revision
  end

  alias eql? ===

  def hash
    "#{self.tags.hashed}/#{self.name}-#{self.version}%#{self.slot}".hash
  end

  def to_h
    result = {}

    [:tags, :name, :version, :slot, :revision, :repository, :flavor, :features].each {|name|
      result[name] = self.send(name) unless self.send(name).nil?
    }

    return result
  end

  def to_s (type=:whole)
    case type
      when :whole; "#{self.to_s(:name)}#{"-#{@version}" if @version}#{"%#{@slot}" if @slot}"
      when :name;  "#{@tags}/#{@name}"
    end
  end
end

end
