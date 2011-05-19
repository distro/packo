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

require 'packo/system'
require 'packo/extensions'

module Packo; module OS

class Process
  include StructLike

  if Packo::System.host.kernel == 'linux'
    def self.all
      Dir['/proc/*'].inject([]) {|res, pr|
        if pr =~ %r{^/proc/(\d+)$}
          res << Process.new($1, {
            name: File.read(File.join(pr, 'comm')).strip,
            command: File.read(File.join(pr, 'cmdline')).strip
          })
        else
          res
        end
      }
    end
  else
    fail 'Unsupported platform, contact the developers please.'
  end

  def self.from_id (id)
    Process.new(id)
  end

  def self.kill (what, signal=:INT)
    if what.is_a?(String) || what.is_a?(Regexp)
      OS::Process.all.each {|p|
        p.kill(signal) if p.command.match(what)
      }
    else
      OS::Process.from_id(what).kill(signal)
    end
  end

  attr_reader :id

  def initialize (id, data={})
    @id   = id
    @data = data
  end

  def kill (signal=:INT, wait=true)
    ::Process.kill(signal, @id)

    if wait
      ::Process.wait(@id)
    end
  end
end

end; end

