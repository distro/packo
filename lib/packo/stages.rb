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

module Packo

class Stages
  attr_reader :package, :stages, :callbacks

  def initialize (package)
    @package = package

    @stages    = []
    @callbacks = {}
  end

  def add (name, options, method)
    obj = options[:before] || options[:after]
    off = (options[:before]) ? 0 : +1

    @stages.delete_if {|stage|
      stage[:name] == name
    }
    
    @stages.insert(@stages.index(obj) || 0 + off, { :name => name, :method => method })

    @stages.compact!
  end

  def register (what, callback)
    (@callbacks[what.to_sym] ||= []) << callback
  end

  def call (what, *args)
    result = []

    (@callbacks[what.to_sym] ||= []).each {|callback|
      begin
        result << callback.call(*args)
      rescue Exception => e
        result << e
      end
    }

    return result
  end
end

end
