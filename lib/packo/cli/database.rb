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

require 'packo/system'
require 'packo/cli'

module Packo; module CLI

class Database < Thor
  include Thor::Actions
  include Database::Helpers

  class_option :help, :type => :boolean, :desc => 'Show help usage'

  desc 'export WHAT [OPTIONS]', 'Export a database'
  map '-e' => :export
  method_option :output, :type => :string, :aliases => '-o', :desc => 'Output to a file instead of stdout'
  def export (*what)
    
  end

  desc 'import FILE... [OPTIONS]', 'Import an exported database'
  map '-i' => :import
  def import (*files)
    files.each {|file|
      Definition.open(file).commit
    }
  end
end

end; end
