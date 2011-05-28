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

require 'packo'

require 'datamapper'

module DataMapper

module Adapters
  class DataObjectsAdapter < AbstractAdapter
    private
      def operation_statement(operation, qualify)
        statements  = []
        bind_values = []

        operation.each do |operand|
          statement, values = conditions_statement(operand, qualify)
          next unless statement
          statements << statement
          bind_values.concat(values) if values
        end

        statement = statements.join(" #{operation.slug.to_s.upcase} ")

        if statements.size > 1
          statement = "(#{statement})"
        end

        return (statement.empty? ? nil : statement), bind_values
      end
  end
end

if Packo::System.env[:DEBUG].to_i > 2
  Logger.new($stdout, :debug)
end

Model.raise_on_save_failure = true

class Property
  class Version < String
    # Hopefully the max length of a version won't go over 255 chars
    length 255

    def custom?
      true
    end

    def primitive? (value)
      value.is_a?(Versionomy::Value)
    end

    def valid? (value, negated = false)
      super || primitive?(value) || value.is_a?(::String)
    end

    def load (value)
      return if value.to_s.empty?

      whole, version, format = value.to_s.match(/^(.+?):([^:]+)$/).to_a

      Versionomy.parse(version, format)
    end

    def dump (value)
      return unless value

      "#{value}:#{Versionomy::Format.canonical_name_for(value.format)}"
    end

    def typecast_to_primitive (value)
      load(value)
    end
  end

  class Location < String
    length 2048

    def custom?
      true
    end

    def primitive? (value)
      value.is_a?(Packo::Location)
    end

    def valid? (value, negated = false)
      super || primitive?(value) || value.is_a?(::String)
    end

    def load (value)
      return if value.to_s.empty?

      Packo::Location.parse(value)
    end

    def dump (value)
      return unless value

      value.to_s
    end

    def typecast_to_primitive (value)
      load(value)
    end
  end
end

begin
  setup :default, Packo::System.env[:DATABASE]
rescue Exception => e
  Packo::CLI.warn "Could not setup a connection with #{Packo::System.env[:DATABASE]}: #{e.message}"
end

require 'packo/models/installed_package'
require 'packo/models/repository'
require 'packo/models/selector'

finalize

begin
  auto_upgrade!
rescue Exception => e
  Packo::CLI.warn "Could not migrate the :database => #{e.message}"
end

end

module Packo

module Models
  def self.transactions
    @@transactions ||= []
  end

  def self.transaction (&block)
    transaction = DataMapper::Transaction.new(DataMapper.repository)
    transaction.begin

    Models.transactions << transaction

    begin
      transaction.within &block
    rescue Exception => e
      transaction.rollback unless transaction.rollback?

      raise e
    end

    transaction.commit
  end

  def self.search (expression, options={})
    packages = []

    if options[:name] && !options[:name].to_s.empty?
      repository = Packo::Repository.parse(options[:name] || options[:repository])

      if options[:type] && Packo::Repository::Types.member?(options[:type].to_s.to_sym)
        repository.type = options[:type]
      end

      if repository = Models::Repository.first(repository.to_hash)
        packages << repository.search(expression, options)
      end
    else
      Packo::Repository::Types.each {|t|
        if options[:type].nil? || options[:type] == 'all' || options[:type] == t
          Models::Repository.all(:type => t).each {|repository|
            packages << repository.search(expression, options)
          }
        end
      }
    end

    packages.flatten.compact.map {|package|
      Package.wrap(package)
    }
  end

  def self.remote (name)
    Models::Repository::Remote.first(Packo::Repository.parse(name).to_hash)
  end

  def self.search_installed (expression, options={})
    Models::InstalledPackage.search(expression, options).map {|pkg|
      Package.wrap(pkg)
    }
  end

  def self.exists? (path)
    Models::InstalledPackage::Content.first(:path => path, :type.not => :dir).package rescue false
  end
end

end
