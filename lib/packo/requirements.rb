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

require 'sys/filesystem'

class Numeric
  module Scalar
    ['', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y'].each {|key|
      (class << self; self; end).__send__(:define_method, key + 'B') {
        self * (1024 ** MULTIPLIERS.index(key))
      }
    }

    def b
      self.to_f / 8
    end
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

begin
  require 'Win32API'

  class Ram
    class MEMORYSTATUS < Struct.new(:dwLength, :dwMemoryLoad, :dwTotalPhys, :dwAvailPhys, :dwTotalPageFile, :dwAvailPageFile, :dwTotalVirtual, :dwAvailVritualPhys)
    end

    class << self
      def total
        self.status.dwTotalPageFile
      end

      def free
        self.status.dwAvailPageFile
      end

      def status
        @__status__ ||= Win32API.new('kernel32', 'GlobalMemoryStatus', 'P', 'V')
        x = ([1] * 8).pack('LLIIIIII')
        @__status__.call(x)
        x = MEMORYSTATUS.new(*x.unpack('LLIIIIII'))
        x.dwMemoryLoad = 100.0 - 100.0 / x.dwTotalPageFile * x.dwAvailPageFile
        x
      end
    end
  end
rescue LoadError
  class Ram
    class << self
      def free
        stat = self.status
        stat[:memfree] + stat[:buffers] + stat[:cached]
      end

      def total
        self.status[:memtotal]
      end

      def status
        Hash[File.read('/proc/meminfo').each_line.map {|l|
          if l =~ /^(\w+):\s+(\d+)/
            [$1.downcase.to_sym, $2.to_i * 1024]
          end
        }.compact]
      end
    end
  end
end
end

module Packo

class Requirements
  def self.disk(*args)
    opts, point = args.partition {|x| x.is_a?(Hash) }
    point = point.first || Sys::Filesystem.mounts.first.mount_point
    opts = opts.inject(:merge)

    return false if !(stat = Sys::Filesystem.stat(point))

    return false if opts[:free] and stat.free < opts[:free]

    return false if opts[:total] and stat.total < opts[:total]

    true
  end

  def self.memory(opts = {})
    return false if opts[:free] and Sys::Ram.free < opts[:free]

    return false if opts[:total] and Sys::Ram.total < opts[:total]

    true
  end
end

end
