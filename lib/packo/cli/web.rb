# encoding: utf-8
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
require 'packo/cli'
require 'packo/web'

module Packo; module CLI

class Web < Thor
  include Thor::Actions

  class_option :help, type: :boolean, desc: 'Show help usage'

  desc 'start [OPTIONS]', 'Start the web interface'
  method_option :host, type: :string,  default: '127.0.0.1', aliases: '-h', desc: 'Set on what address to listen to'
  method_option :port, type: :numeric, default: 1337,        aliases: '-p', desc: 'Set on what port to listen to'
  def start
    Packo::Web.run!({
      bind: options[:host]
    }.merge(options))
  end
end

end; end
