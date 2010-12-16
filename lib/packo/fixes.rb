# Copyrights to their respective owners, and license as their license.
#
# This file is just for bug fixes I made to make packo work with those libraries.
#
# They will stay here until the gems are updated.

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
end
