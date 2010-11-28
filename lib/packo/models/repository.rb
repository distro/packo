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

  Types = [:binary, :source, :virtual]

  property :id, Serial

  property :name, String,                           :required => true
  property :type, Enum[:binary, :source, :virtual], :required => true

  property :uri,  URI,  :required => true
  property :path, Text, :required => true

  has n, :packages

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
      when :binary;  Binary.first_or_new(:repo => self)
      when :source;  Source.first_or_new(:repo => self)
      when :virtual; Virtual.first_or_new(:repo => self)
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

      conditions = {}

      op = exact ? :eql : :like

      conditions[DataMapper::Query::Operator.new(:name, op)]    = package.name if package.name
      conditions[DataMapper::Query::Operator.new(:version, op)] = package.version if package.version
      conditions[DataMapper::Query::Operator.new(:slot, op)]    = package.slot if package.slot

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
              SELECT ____u_t_#{index}.package_id

              FROM packo_models_package_tags AS ____u_t_#{index}

              INNER JOIN packo_models_tags AS ____t_#{index}
                  ON ____u_t_#{index}.tag_id = ____t_#{index}.id AND ____t_#{index}.name = ?
          ) AS ____t_i_#{index}
              ON packo_models_repository_packages.id = ____t_i_#{index}.package_id
        }

        if (replace = names[index]).match(/[\s&!|]/)
          replace = %{"#{replace}"}
        end

        expression.gsub!(/([\s()]|\G)!\s*#{Regexp.escape(replace)}([\s()]|$)/, "\\1 (____t_i_#{index}.package_id IS NULL) \\2")
        expression.gsub!(/([\s()]|\G)#{Regexp.escape(replace)}([\s()]|$)/, "\\1 (____t_i_#{index}.package_id IS NOT NULL) \\2")
      }

      expression.gsub!(/([\G\s()])&&([\s()\A])/, '\1 AND \2')
      expression.gsub!(/([\G\s()])\|\|([\s()\A])/, '\1 OR \2')
      expression.gsub!(/([\G\s()])!([\s()\A])/, '\1 NOT \2')

      return joins, names, expression
    end

    def _find_by_expression (expression)
      joins, names, expression = _expression_to_sql(expression)

      # It's an array to use the ? thing of select
      repository.adapter.select(*[%{
          SELECT DISTINCT packo_models_repository_packages.id

          FROM packo_models_repository_packages

          #{joins}

          WHERE #{expression}
      }].concat(names))
    end
end

end; end
