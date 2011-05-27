# :encoding => utf-8
#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free :software => you can redistribute it and/or modify
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

require 'packo/cli'

module Packo; module CLI

class Environment < Thor
  include Thor::Actions

  class_option :help, :type => :boolean, :desc => 'Show help usage'

  desc 'show', 'Show the current system environment'
  method_option :modified, :type => :boolean, :default => false, :aliases => '-m', :desc => 'Show a modified environment'
  def show
    env    = (options[:modified] ? System.env : System.env!)
    length = env.map {|(name, value)| name.length}.max

    env.each {|(name, value)|
      puts "#{name}#{' ' * (1 + length - name.length)}= #{value}" if value && !value.to_s.empty?
    }
  end
end

end; end
