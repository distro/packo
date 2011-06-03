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

module FFI
  module Library
    def has_function? (sym, libraries=[])
      if libraries.empty?
        libraries << FFI::Library::LIBC
      end

      libraries.any? {|lib|
        DynamicLibrary.new(lib, 0).find_function(sym.to_s) rescue nil
      }
    end

    def attach_function! (*args, &block)
      begin
        attach_function(*args, &block)
      rescue Exception => e
        false
      end
    end
  end
end

module Packo; module OS

FFI.find_type(:size_t) rescue FFI.typedef(:ulong, :size_t)

module Functions
  extend FFI::Library

  ffi_lib FFI::Library::LIBC

  attach_function!('sysconf', [:int], :long)

  attach_function!('sysctl', [:pointer, :uint, :pointer, :pointer, :size_t], :int)

  attach_function!('sysctlbyname', [:string, :pointer, :pointer, :pointer, :size_t], :int)
end

if Functions.respond_to?(:sysconf) || Functions.respond_to?(:sysctl) || Functions.respond_to?(:sysctlbyname)
  # TODO: implement it, use all the available options
  def self.sysctl (name)
    # count = FFI::MemoryPointer.new(:int)
    # size  = FFI::MemoryPointer.new(:size_t).put_int(0, count.size)

    # Functions.sysctlbyname('hw.ncpu', count, size, nil, 0)
    # count.get_int(0)
  end
end

end; end
