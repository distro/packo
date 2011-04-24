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

require 'thor'
require 'colorb'

class Thor
  class << self
    def help(shell, subcommand = false)
      list = printable_tasks(true, subcommand)
      Thor::Util.thor_classes_in(self).each do |klass|
        list += klass.printable_tasks(false)
      end

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
end

module Packo

module CLI
  def self.info (text)
    puts "#{'*'.green.bold} #{text}"
  end

  def self.warn (text)
    puts "#{'*'.yellow.bold} #{text}"
  end

  def self.fatal (text)
    puts "#{'*'.red} #{text}"
  end
end

end

['INT', 'QUIT', 'ABRT', 'TERM', 'TSTP'].each {|sig|
  trap sig do
    puts 'Aborting.'

    Process.exit! 0
  end
}
