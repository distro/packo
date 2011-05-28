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

class Filesystem
  if Packo::System.host.posix?
    extend FFI::Library

    ffi_lib FFI::Library::LIBC
    
    attach_function 'statvfs', [:string, :pointer], :int

    class StatVFS < FFI::Struct
      layout \
        :f_bsize,   :ulong,
        :f_frsize,  :ulong,
        :f_blocks,  :fsblkcnt_t,
        :f_bfree,   :fsblkcnt_t,
        :f_bavail,  :fsblkcnt_t,
        :f_files,   :fsblkcnt_t,
        :f_ffree,   :fsblkcnt_t,
        :f_favail,  :fsblkcnt_t,
        :f_fsid,    :uint64,
        :f_flag,    :ulong,
        :f_namemax, :ulong,
        :__f_spare,   [:int, 6]
    end

    def self.stat (path=nil)
      path ||= '/'
      fs     = StatVFS.new

      if statvfs(path, fs.pointer) < 0
        raise ArgumentError.new "Mount point '#{path}' not found"
      end

      return OpenStruct.new(
        :path => path,

        :total => fs[:f_blocks] * fs[:f_frsize],
        :free =>  fs[:f_bfree] * fs[:f_bsize]
      )
    end
  else
    fail 'Unsupported platform, contact the developers please.'
  end
end

end; end
