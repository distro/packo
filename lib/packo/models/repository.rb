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

require 'packo/models/repository/package'

require 'packo/models/repository/binary'
require 'packo/models/repository/source'
require 'packo/models/repository/virtual'

module Packo; module Models

class Repository
  include DataMapper::Resource

  property :id, Serial

  property :name, String,                           :required => true
  property :type, Enum[:binary, :source, :virtual], :required => true

  property :uri,  URI,  :required => true
  property :path, Text, :required => true

  has n, :packages, :constraint => :destroy

  after :create do |repo|
    case repo.type
      when :binary;  Binary.create(:repo => repo)
      when :source;  Source.create(:repo => repo)
      when :virtual; Virtual.create(:repo => repo)
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
      when :binary;  Binary.first_or_create(:repo => self)
      when :source;  Source.first_or_create(:repo => self)
      when :virtual; Virtual.first_or_create(:repo => self)
    end
  end

  def URI
    case type
      when :binary;  data.mirrors.to_a.map {|m| m.uri}.join("\n")
      when :source;  data.address
      when :virtual; data.address
    end
  end

  def search (expression, exact=false)
    if expression.start_with?('[') && expression.end_with?(']')
      result = _find_by_expression(expression[1, expression.length - 2]).map {|id|
        Package.get(id)
      }
    else
      if matches = expression.match(/^([<>]?=?)/)
        validity = ((matches[1] && !matches[1].empty?) ? matches[1] : nil)
        expression = expression.sub(/^([<>]?=?)/, '')

        validity = nil if validity == '='
      else
        validity = nil
      end

      package = Packo::Package.parse(expression)

      conditions = { :order => [:name.asc] }

      if exact
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

      if validity
        result = result.select {|pkg|
          case validity
            when '>';  pkg.version >  package.version
            when '>='; pkg.version >= package.version
            when '<';  pkg.version <  package.version
            when '<='; pkg.version <= package.version
          end
        }
      end
    end

    return result
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

    def _find_by_expression (expression)
      unless repository.adapter.respond_to? :select
        raise RuntimeError.new('The adapter does not support tag searching')
      end

      joins, names, expression = _expression_to_sql(expression)

      repository.adapter.select(%{
        SELECT DISTINCT packo_models_repository_packages.id

        FROM packo_models_repository_packages

        #{joins}

        WHERE packo_models_repository_packages.repo_id = ? #{"AND (#{expression})" if !expression.empty?}
      }, *(names + [id]))
    end
end

end; end
