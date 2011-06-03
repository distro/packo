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

require 'packo/os'

FFI.find_type(:size_t) rescue FFI.typedef(:ulong, :size_t)

module Packo; module OS

class CPU
  extend FFI::Library

  ffi_lib FFI::Library::LIBC

  if (attach_function('sysconf', [:int], :long) rescue nil) && sysconf(84) != -1
    def self.cores
      sysconf(84)
    end
  elsif (attach_function('sysctlbyname', [:string, :pointer, :pointer, :pointer, :size_t], :int) rescue nil)
    def self.cores
      count = FFI::MemoryPointer.new(:int)
      size  = FFI::MemoryPointer.new(:size_t).put_int(0, count.size)

      self.sysctlbyname('hw.ncpu', count, size, nil, 0)
      count.get_int(0)
    end
  else
    fail 'Unsupported platform, contact the developers please.'
  end
end

end; end
