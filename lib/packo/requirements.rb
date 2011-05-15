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

require 'sys/filesystem'

require 'packo/system'

class Numeric
  module Scalar
    Multipliers = ['', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y']
    
    Multipliers.each {|key|
      define_method "#{key}B" do
        self * (1024 ** Multipliers.index(key))
      end
    }
  end
end

class Integer
  include Numeric::Scalar
end

class Float
  include Numeric::Scalar
end

class Rational
  include Numeric::Scalar
end

module Sys
  class Filesystem
    class Stat
      def free
        self.blocks_available * self.fragment_size
      end

      def total
        self.blocks * self.fragment_size
      end
    end
  end

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
          :dwTotalVirtual, :dwAvailVritualPhys
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
      def self.status
        warn 'Packo::Requirements does not support this operating system'

        { total: 9001.GB, free: 9001.GB }
      end
    end
  end
end

module Packo

class Requirements
  def self.disk (path=nil, option)
    path ||= Sys::Filesystem.mounts.first.mount_point

    return false if !(stat = Sys::Filesystem.stat(path))

    return false if options[:free] && stat.free < options[:free]

    return false if options[:total] && stat.total < options[:total]

    true
  end

  def self.memory (options={})
    return false if options[:free] && Sys::Ram.free < options[:free]

    return false if options[:total] && Sys::Ram.total < options[:total]

    true
  end
end

end
