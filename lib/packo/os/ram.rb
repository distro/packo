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
  def self.total
    self.status[:total]
  end

  def self.free
    self.status[:free]
  end

  if Packo::System.host.kernel == 'windows'
    require 'Win32API'

    __global_memory_status = Win32API.new('kernel32', 'GlobalMemoryStatus', 'P', 'V')

    def self.status
      result = ([1] * 8).pack('LLIIIIII'); __global_memory_status.call(result)

      result = Struct.new(
        :dwLength, :dwMemoryLoad,
        :dwTotalPhys, :dwAvailPhys,
        :dwTotalPageFile, :dwAvailPageFile,
        :dwTotalVirtual, :dwAvailVirtualPhys
      ).new(*result.unpack('LLIIIIII'))

      { total: result.dwTotalPageFile, free: result.dwAvailPageFile }
    end
  elsif Packo::System.host.kernel == 'linux'
    def self.status
      result = Hash[File.read('/proc/meminfo').each_line.map {|l|
        if l =~ /^(\w+):\s+(\d+)/
          [$1.downcase.to_sym, $2.to_i * 1024]
        end
      }.compact]

      { total: result[:memtotal], free: result[:memfree] + result[:buffers] + result[:cached] }
    end
  else
    fail 'Unsupported platform, contact the developers please.'
  end
end

end; end
