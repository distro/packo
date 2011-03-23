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

require 'packo'
require 'packo/models'

module Packo; module CLI

class Select < Thor
  include Thor::Actions

  class_option :help, type: :boolean, desc: 'Show help usage'

  desc 'add NAME DESCRIPTION PATH', 'Add a module to the database'
  def add (name, description, path)
    Models::Selector.first_or_create(name: name).update(description: description, path: path)

    CLI.info "#{name} added"
  end

  desc 'delete NAME', 'Delete a module from the database'
  def delete (name)
    selector = Models::Selector.first(name: name)

    if !selector
      fatal "#{name} doesn't exist"
      exit! 30
    end

    selector.destroy

    CLI.info "#{name} deleted"
  end
end

Models::Selector.all.each {|selector|
  Select.class_eval %{
    desc '#{selector.name} [ARGUMENTS...]', '#{selector.description}'
    def #{selector.name} (*arguments)
      system(*(['#{selector.path}'] + ARGV[1, ARGV.length]).compact)
    end
  }
}

end; end
