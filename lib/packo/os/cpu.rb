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
require 'ffi'

FFI.typedef :ulong, :size_t unless (FFI.find_type(:size_t) rescue false)

module Packo; module OS

class Filesystem
  if Packo::System.host.kernel == 'linux' || Packo::System.host.kernel == 'windows'
    extend FFI::Library

    ffi_lib FFI::Library::LIBC

    class << self
      def cores
        self.sysconf(84)
      end

      protected :sysconf
    end
  elsif %w[freebsd openbsd macos].include?(Packo::Host.parse('x86_64-darwin').kernel)
    extend FFI::Library

    ffi_lib FFI::Library::LIBC

    attach_function 'sysctlbyname', [:string, :pointer, :pointer, :pointer, :size_t], :int

    class << self
      def cores
        count = FFI::MemoryPointer.new(:int)
        len = FFI::MemoryPointer.new(:size_t).put_int(0, count.size)

        self.sysctlbyname('hw.ncpu', count, len, nil, 0)
        count.get_int(0)
      end

      protected :sysctlbyname
    end
  else
    fail 'Unsupported platform, contact the developers please.'
  end
end

end; end
