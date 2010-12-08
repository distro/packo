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
    )
  end

  def self.arch (value=Environment.new(nil, true)[:ARCH])
    case value
      when 'core2'; 'x86_64'
      when 'x86';   'i686'

      when 'i386', 'i486', 'i586', 'i686',
           'amd64', 'x86_64'
      ; value

      else; raise ArgumentError.new('Architecture not supported')
    end
  end

  def self.vendor (value=Environment.new(nil, true)[:VENDOR])
    case value
      when 'pc'; value

      else; 'unknown'
    end
  end

  def self.kernel (value=Environment.new(nil, true)[:KERNEL])
    case value
      when 'windows'; 'cygwin'
      when 'mac';     'darwin'
      when 'linux';   'linux'

      else; raise ArgumentError.new('Kernel not supported')
    end
  end

  def self.misc (value=Environment.new(nil, true)[:MISC])
    case value
      when 'gnu'; value
    end
  end

  def self.== (value)
    value.is_a?(Host) && self.to_s == value.to_s
  end

  def self.to_s
    Host.new(Environment.new(nil, true)).to_s rescue ''
  end

  attr_reader :arch, :vendor, :kernel, :misc

  def initialize (data)
    self.arch   = data[:ARCH]
    self.vendor = data[:VENDOR]
    self.kernel = data[:KERNEL]
    self.misc   = data[:MISC]

    if !self.misc && data[:LIBC] == 'glibc'
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
    value.is_a?(Host) && self.to_s == value.to_s
  end

  def to_s
    "#{arch}#{"-#{vendor}" if vendor}-#{kernel}#{"-#{misc}" if misc}"
  end
end

end
