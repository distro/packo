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

if Packo::System.host.kernel == 'linux'
  require 'dl/import'
  require 'dl/struct'

  module DL
    module ValueUtil
    def unsigned_value(val, ty)
      case ty.abs
        when TYPE_CHAR
          [val].pack("c").unpack("C")[0]
        when TYPE_SHORT
          [val].pack("s!").unpack("S!")[0]
        when TYPE_INT
          [val].pack("i!").unpack("I!")[0]
        when TYPE_LONG
          [val].pack("l!").unpack("L!")[0]
        when TYPE_LONG_LONG
          [val].pack("q").unpack("Q")[0]
        else
          val
        end
      end
    end
  end
end

module Packo; module OS

class Filesystem
  def self.total (path=nil)
    st = self.stat(path)
    st.f_blocks * st.f_bsize
  end

  def self.free (path=nil)
    st = self.stat(path)
    st.f_bavail * st.f_bsize
  end

  if Packo::System.host.kernel == 'linux'
    extend DL::Importer

    dlload 'libc.so.6'

    extern 'int statvfs(char*, void*)'

    BITS = Packo::System.env[:ARCH] == 'x86_64' ? 64 : 32
    TYPE = (BITS == 64 ? 'unsigned long long' : 'unsigned long')
    STRUCT = struct([
      "unsigned long f_bsize",
      "unsigned long f_frsize",
      "#{TYPE} f_blocks",
      "#{TYPE} f_bfree",
      "#{TYPE} f_bavail",
      "#{TYPE} f_files",
      "#{TYPE} f_ffree",
      "#{TYPE} f_favail",
      "unsigned long f_sid",
    ] + (BITS == 32 ? ["#{TYPE} __f_unused"] : []) + [
      "unsigned long f_flag",
      "unsigned long f_namemax",
      "int __f_spare[6]"
    ])

    class << self
      def stat (path=nil)
        path ||= '/'
        fs = STRUCT.malloc
        fail "Mount point '#{path}' not found" if statvfs(path, fs) < 0
        fs
      end

      protected :statvfs
    end
  else
    fail 'Unsupported platform, contact the developers please.'
  end
end

end; end
