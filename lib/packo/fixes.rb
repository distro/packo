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

class Optitron
  module ClassDsl
    module ClassMethods
      def dispatch(args = ARGV, &blk)
        optitron_parser.target = blk ? blk.call : new
        build
        response = optitron_parser.parse(args)
        if response.valid?
          optitron_parser.target.params = response.params
          args = response.args
          parser_args = optitron_parser.commands.assoc(response.command).last.args
          while (args.size < parser_args.size && !(parser_args[args.size].type == :greedy && parser_args[args.size].default.nil?))
            args << parser_args[args.size].default 
          end

          optitron_parser.target.send(response.command.to_sym, *response.args)
        else
          puts optitron_parser.help

          unless response.args.empty?
            puts response.error_messages.join("\n")
          end
        end
      end
    end
  end

  class Parser
    def parse(argv = ARGV)
      tokens = Tokenizer.new(self, argv).tokens
      response = Response.new(self, tokens)
      options = @options 
      args = @args
      unless @commands.empty?
        potential_cmd_toks = tokens.select { |t| t.respond_to?(:lit) }
        if cmd_tok = potential_cmd_toks.find { |t| @commands.assoc(t.lit) }
          tokens.delete(cmd_tok)
          response.command = cmd_tok.lit
          options += @commands.assoc(cmd_tok.lit).last.options
          args = @commands.assoc(cmd_tok.lit).last.args
        elsif !potential_cmd_toks.empty? && @target.respond_to?(:command_missing)
          command = potential_cmd_toks.first.lit
          response.command = 'command_missing'
          @commands << [response.command, Option::Cmd.new(response.command)]
          @commands.assoc(response.command).last.options.insert(-1, *tokens.select { |t| !t.respond_to?(:lit) }.map { |t|
            t.is_a?(Tokenizer::Named) ?
              Option::Opt.new(t.name, nil, :short_name => t.name) :
              Option::Opt.new(t.name, nil, :type => (t.value ? :string : :boolean))
          })
          @commands.assoc(response.command).last.args <<
            Option::Arg.new('command', 'Command name', :type => :string) <<
            Option::Arg.new('args', 'Command arguments', :type => :greedy)
          options += @commands.assoc(response.command).last.options
          args = @commands.assoc(response.command).last.args
        else
          potential_cmd_toks.first ?
            response.add_error('an unknown command', potential_cmd_toks.first.lit) :
            response.add_error('unknown command')
        end
      end
      parse_options(tokens, options, response)
      parse_args(tokens, args, response)
      response.validate
      response
    end
  end
end
