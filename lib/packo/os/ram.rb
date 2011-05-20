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

module Packo; module OS

class Ram
  if File.readable?('/proc/meminfo')
    def self.status
      result = Hash[File.read('/proc/meminfo').each_line.map {|line|
        whole, name, value = line.match(/^(\w+):\s+(\d+)/).to_a

        next unless whole

        [name.downcase.to_sym, value.to_i * 1024]
      }.compact]

      return OpenStruct.new(
        physical: OpenStruct.new(
          total: result[:memtotal],
          free:  result[:memfree]
        ),
          
        swap: OpenStruct.new(
          total: result[:swaptotal],
          free:  result[:swapfree]
        ),

        virtual: OpenStruct.new(
          total: result[:memtotal] + result[:swaptotal],
          free:  result[:memfree] + result[:swapfree]
        )
      )
    end
  else
    fail 'Unsupported platform, contact the developers please.'
  end
end

end; end
