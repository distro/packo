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

require 'versionomy'

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

        data[:features] = matches[3]
        data[:flavor]   = matches[5]

        matches = matches[1].match(/^(.*?)(?:-(\d.*?))?(?:%(.*?))?(?:@(.*?))?$/)

        data[:tags] = matches[1].split('/')

        if matches[1][matches[1].length - 1] != '/'
          data[:name] = data[:tags].pop
        end

        data[:version] = matches[2]
        data[:slot]    = matches[3]
        
        if matches[4]
          data[:repository] = Repository.parse(matches[4])
        end
    end

    Package.new(data)
  end

  def self.wrap (model)
    case model
      when Models::Repository::Package; Package.new(
        tags:     model.tags.map {|t| t.name},
        name:     model.name,
        version:  model.version,
        slot:     model.slot,
        revision: model.revision,

        features: (case model.repo.type
          when :binary; model.data.features
          when :source; model.data.features.map {|f| f.name}.join(' ')
        end),

        description: model.description,
        homepage:    model.homepage,
        license:     model.license,

        repository: Repository.wrap(model.repo),
        model:      model
      )

      when Models::InstalledPackage; Package.new(
        tags:     model.tags.map {|t| t.name},
        name:     model.name,
        version:  model.version,
        slot:     model.slot,
        revision: model.revision,

        flavor:   model.flavor,
        features: model.features,

        repository: model.repo ? Repository.parse(model.repo) : nil,
        model:      model
      )

      else; raise "I do not know #{model.class}."
    end
  end

  attr_reader :model, :environment

  def environment!; @environmentClean; end

  alias env  environment
  alias env! environment!

  def initialize (data)
    @data             = {}
    @environment      = Environment.new(self)
    @environmentClean = Environment.new(self, true)
    @export           = []

    data.each {|name, value|
      self.send "#{name}=", value
    }

    self.tags = [] unless self.tags

    @model = data[:model]
  end

  def method_missing (id, *args)
    id = id.to_s.sub(/[=?]$/, '').to_sym

    if args.length == 0
      return @data[id]
    else
      if respond_to? "#{id}="
        send "#{id}=", *args
      else
        @data[id] = (args.length > 1) ? args : args.first
      end
    end
  end

  def envify!
    environment.apply!

    environment[:FLAVOR].split(/\s+/).each {|element|
      matches = element.match(/^([+-])?(.+)$/)

      (matches[1] == '-') ?
        self.flavor.send("not_#{matches[2]}!") :
        self.flavor.send("#{matches[2]}!")
    }

    "#{environment[:FEATURES]} #{environment[:USE]}".split(/\s+/).each {|feature|
      feature = Feature.parse(feature)

      self.features {
        next if !self.has?(feature.name)

        if feature.enabled?
          self.get(feature.name).enable!
        else
          self.get(feature.name).disable!
        end
      }
    }
  end

  def export! (*names)
    @export.insert(-1, *names)
    @export.compact!
    @export.uniq!
  end

  def exports
    result = {}

    @export.each {|export|
      result[export] = @data[export]
    }

    result
  end

  def masked?; !!@masked                          end
  def mask!;   @masked = true if @masked != false end
  def unmask!; @masked = false                    end

  def tags= (*value)
    @data[:tags] = Tags.parse(value.length > 1 ? value : value.first) unless value.empty? || !value.first
  end

  def version= (value)
    @data[:version] = ((value.is_a?(Versionomy::Value)) ? value : Versionomy.parse(value.to_s)) if value
  end

  def slot= (value)
    @data[:slot] = (value.to_s.empty?) ? nil : value.to_s
  end

  def revision= (value)
    @data[:revision] = value.to_i rescue 0
  end

  def flavor= (value)
    @data[:flavor] = ((value.is_a?(Flavor)) ? value : Flavor.parse(value.to_s))
  end

  def features= (value)
    @data[:features] = ((value.is_a?(Features)) ? value : Features.parse(value.to_s))
  end

  def == (package)
    name == package.name &&
    tags == ((defined?(Packo::Models) && package.is_a?(Packo::Models::Repository::Package)) ? Package.wrap(package).tags : package.tags)
  end

  def === (package)
    name     == package.name &&
    tags     == ((defined?(Packo::Models) && package.is_a?(Packo::Models::Repository::Package)) ? Package.wrap(package).tags : package.tags) &&
    version  == package.version &&
    slot     == package.slot &&
    revision == package.revision
  end

  alias eql? ===

  def hash
    "#{self.tags.hashed}/#{self.name}-#{self.version}%#{self.slot}".hash
  end

  def to_hash
    result = {}

    [:tags, :name, :version, :slot, :revision, :repository, :flavor, :features].each {|name|
      if tmp = self.send(name)
        result[name] = tmp
      end
    }

    return result
  end

  def to_s (type=:whole)
    case type
      when :whole; "#{self.to_s(:name)}#{"-#{version}" if version}#{"%#{slot}" if slot}"
      when :name;  "#{tags}/#{name}"
    end
  end
end

end
