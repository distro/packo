# The license of this file is Thor's license

require 'thor'

class Thor
	class << self
		def help(shell, subcommand = false)
			list = printable_tasks(true, subcommand)
			Thor::Util.thor_classes_in(self).each do |klass|
				list += klass.printable_tasks(false)
			end

			list.map! {|(cmd, desc)|
				[cmd.sub(/^.*?(\s|$)/, ''), desc]
			}

			shell.say 'Commands:'
			shell.print_table(list, ident: 2, truncate: true)
			shell.say
			class_options_help(shell)
		end
	end

	module Base
		module ClassMethods
			def handle_no_task_error(task) #:nodoc:
				if $thor_runner
					raise UndefinedTaskError, "Could not find command #{task.inspect} in #{namespace.inspect} namespace."
				else
					raise UndefinedTaskError, "Could not find command #{task.inspect}."
				end
			end
		end
	end

	desc 'help [COMMAND]', 'Describe available commands or one specific command'
	def help (task=nil, subcommand=false)
		task ? self.class.task_help(shell, task) : self.class.help(shell, subcommand)
	end
end

require 'packo/cli'
