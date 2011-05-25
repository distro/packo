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

require 'packo/repository'

require 'packo/models/repository/remote'
require 'packo/models/repository/package'

require 'packo/models/repository/binary'
require 'packo/models/repository/source'
require 'packo/models/repository/virtual'

module Packo; module Models

class Repository
  include DataMapper::Resource

  property :id, Serial

  property :type, Enum[:binary, :source, :virtual], required: true
  property :name, String,                           required: true

  property :location, Location, required: true
  property :path,     Text,     required: true

  has n, :packages, constraint: :destroy

  after :create do |repo|
    case repo.type
      when :binary;  Binary.create(repo: repo)
      when :source;  Source.create(repo: repo)
      when :virtual; Virtual.create(repo: repo)
    end
  end

  after :save do |repo|
    repo.data.save if repo.data
  end

  after :destroy do |repo|
    repo.data.destroy! if repo.data
  end

  def data
     case type
      when :binary;  Binary.first_or_create(repo: self)
      when :source;  Source.first_or_create(repo: self)
      when :virtual; Virtual.first_or_create(repo: self)
    end
  end

  def to_hash
    Hash[
      type:     self.type,
      name:     self.name,
      location: self.location,
      path:     self.path
    ]
  end

  def URI
    case type
      when :binary;  data.mirrors.to_a.map {|m| m.uri}.join("\n")
      when :source;  data.location.to_s
      when :virtual; data.location.to_s
    end
  end

  def search (expression, options={})
    if expression.start_with?('(') && expression.end_with?(')')
      result = find_by_expression(expression[1, expression.length - 2])
    else
      whole, validity, package, expression = expression.match(/^([<>]?=?)?(.+?)\s*(?:\((.*)\))?$/).to_a

      package = Packo::Package.parse(package || '')

      conditions = { order: [:name.asc] }

      if options[:exact]
        conditions[:name]    = package.name    if package.name
        conditions[:version] = package.version if package.version
        conditions[:slot]    = package.slot    if package.slot
      else
        conditions[:name.like]    = "%#{package.name}%" if package.name
        conditions[:version.like] = package.version     if package.version
        conditions[:slot.like]    = "%#{package.slot}%" if package.slot
      end

      result = packages.all(conditions)

      if !package.tags.empty?
        result = result.to_a.select {|pkg|
          Packo::Package.wrap(pkg).tags == package.tags
        }
      end

      if validity && !validity.empty?
        result = result.select {|pkg|
          case validity
            when '~', '~=' then true
            when '>'       then pkg.version >  package.version
            when '>='      then pkg.version >= package.version
            when '<'       then pkg.version <  package.version
            when '<='      then pkg.version <= package.version
            else                pkg.version == package.version
          end
        }
      end

      if expression && !expression.empty?
        expression = Packo::Package::Tags::Expression.parse(expression)

        result.select! {|pkg|
          expression.evaluate(Packo::Package.wrap(pkg))
        }
      end
    end

    return result
  end

  def find_by_expression (expression)
    if DataMapper.repository.adapter.respond_to? :select
      joins, names, expression = _expression_to_sql(expression)

      (repository.adapter.select(%{
        SELECT DISTINCT packo_models_repository_packages.id

        FROM packo_models_repository_packages

        #{joins}

        WHERE packo_models_repository_packages.repo_id = ? #{"AND (#{expression})" if !expression.empty?}
      }, *(names + [id])) rescue []).map {|id|
        Package.get(id)
      }
    else
      expression = Packo::Package::Tags::Expression.parse(expression)

      packages.all.select {|pkg|
        expression.evaluate(Packo::Package.wrap(pkg))
      }
    end
  end

private
  def _expression_to_sql (value)
    value.downcase!
    value.gsub!(/(\s+and\s+|\s*&&\s*)/i, ' && ')
    value.gsub!(/(\s+or\s+|\s*\|\|\s*)/i, ' || ')
    value.gsub!(/(\s+not\s+|\s*!\s*)/i, ' !')
    value.gsub!(/\(\s*!/, '(!')

    joins      = String.new
    names      = []
    expression = value.clone

    expression.scan(/(("(([^\\"]|\\.)*)")|([^\s&!|()]+))/) {|match|
      names.push((match[2] || match[4]).downcase)
    }

    names.compact!
    names.uniq!

    names.each_index {|index|
      joins << %{
        LEFT JOIN (
            SELECT _used_tag_#{index}.package_id

            FROM packo_models_package_tags AS _used_tag_#{index}

            INNER JOIN packo_models_tags AS _tag_#{index}
                ON _used_tag_#{index}.tag_id = _tag_#{index}.id AND _tag_#{index}.name = ?
        ) AS _tag_check_#{index}
            ON packo_models_repository_packages.id = _tag_check_#{index}.package_id
      }

      if (replace = names[index]).match(/[\s&!|]/)
        replace = %{"#{replace}"}
      end

      expression.gsub!(/([\s()]|\G)!\s*#{Regexp.escape(replace)}([\s()]|$)/, "\\1 (_tag_check_#{index}.package_id IS NULL) \\2")
      expression.gsub!(/([\s()]|\G)#{Regexp.escape(replace)}([\s()]|$)/, "\\1 (_tag_check_#{index}.package_id IS NOT NULL) \\2")
    }

    expression.gsub!(/([\G\s()])&&([\s()\A])/, '\1 AND \2')
    expression.gsub!(/([\G\s()])\|\|([\s()\A])/, '\1 OR \2')
    expression.gsub!(/([\G\s()])!([\s()\A])/, '\1 NOT \2')

    return joins, names, expression
  end
end

end; end
