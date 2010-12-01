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

require 'packo/models/tag'
require 'packo/models/installed_package/dependency'
require 'packo/models/installed_package/content'

module Packo; module Models

class InstalledPackage
  include DataMapper::Resource

  property :id, Serial

  property :repo, String
  has n,   :tags, :through => Resource, :constraint => :destroy

  property :tags_hashed, String, :length => 40,    :required => true, :unique_index => :a # hashed tags
  property :name,        String,                   :required => true, :unique_index => :a
  property :version,     Version,                  :required => true
  property :slot,        String,  :default => '',                     :unique_index => :a
  property :revision,    Integer, :default => 0

  property :flavors,  Text, :default => ''
  property :features, Text, :default => ''

  property :manual,  Boolean, :default => false
  property :runtime, Boolean, :default => true  # Installed as build or runtime dependency

  has n, :dependencies, :constraint => :destroy
  has n, :contents,     :constraint => :destroy

  def self.search (expression, exact=false, repository=nil)
    if expression.start_with?('[') && expression.end_with?(']')
      result = self._find_by_expression(expression[1, expression.length - 2]).map {|id|
        InstalledPackage.get(id)
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

      conditions[DataMapper::Query::Operator.new(:name, op)]    = package.name    if package.name
      conditions[DataMapper::Query::Operator.new(:version, op)] = package.version if package.version
      conditions[DataMapper::Query::Operator.new(:slot, op)]    = package.slot    if package.slot

      result = InstalledPackage.all(conditions)

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

    if repository
      result.delete_if {|pkg|
        pkg.repo != repository
      }
    end

    return result
  end

  private
    def self._expression_to_sql (value)
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

              FROM packo_models_installed_package_tags AS ____u_t_#{index}

              INNER JOIN packo_models_tags AS ____t_#{index}
                  ON ____u_t_#{index}.tag_id = ____t_#{index}.id AND ____t_#{index}.name = ?
          ) AS ____t_i_#{index}
              ON packo_models_installed_packages.id = ____t_i_#{index}.package_id
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

    def self._find_by_expression (expression, repository)
      joins, names, expression = self._expression_to_sql(expression)

      repository.adapter.select(%{
        SELECT DISTINCT packo_models_installed_packages.id

        FROM packo_models_installed_packages

        #{joins}

        WHERE #{expression}
      }, *names)
    end
end

end; end
