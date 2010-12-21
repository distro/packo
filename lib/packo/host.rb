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

require 'packo/environment'

module Packo

class Host
  def self.parse (text)
    matches = text.match(/^([^-]+)(-([^-]+))?-([^-]+)(-([^-]+))?$/) or return

    Host.new(
      :ARCH   => matches[1],
      :VENDOR => matches[3],
      :KERNEL => matches[4],
      :MISC   => matches[6]
    ) rescue nil
  end

  def self.arch (value=System.env![:ARCH])
    case value
      when 'core2'; 'x86_64'
      when 'x86';   'i686'

      when 'i386', 'i486', 'i586', 'i686',
           'amd64', 'x86_64'
      ; value

      else; raise ArgumentError.new('Architecture not supported')
    end
  end

  def self.vendor (value=System.env![:VENDOR])
    case value
      when 'pc'; value

      else; 'unknown'
    end
  end

  def self.kernel (value=System.env![:KERNEL])
    case value
      when 'windows'; 'cygwin'
      when 'mac';     'darwin'
      when 'linux';   'linux'

      else; raise ArgumentError.new('Kernel not supported')
    end
  end

  def self.misc (value=System.env![:MISC])
    case value
      when 'gnu'; value
    end
  end

  attr_reader :arch, :vendor, :kernel, :misc

  def initialize (data)
    self.arch   = data[:ARCH]
    self.vendor = data[:VENDOR]
    self.kernel = data[:KERNEL]
    self.misc   = data[:MISC]

    if !self.misc && data[:LIBC] == 'glibc' && (self.kernel == 'linux')
      self.misc = 'gnu'
    end

    if self.vendor == 'unknown' && ['x86_64', 'i386', 'i486', 'i586', 'i686'].member?(self.arch)
      self.vendor = 'pc'
    end
  end

  def arch= (value)
    @arch = Host.arch(value)
  end

  def vendor= (value)
    @vendor = Host.vendor(value)
  end

  def kernel= (value)
    @kernel = Host.kernel(value)
  end

  def misc= (value)
    @misc = Host.misc(value)
  end

  def == (value)
    if value.is_a?(Host)
      self.to_s == value.to_s
    else
      !!self.to_s.match(Regexp.new('^' + Regexp.escape(value.to_s).gsub(/\\\*/, '.*?').gsub(/\\\?/, '.') + '$', 'i'))
    end
  end

  alias === ==

  def to_s
    "#{arch}#{"-#{vendor}" if vendor}-#{kernel}#{"-#{misc}" if misc}"
  end
end

end
