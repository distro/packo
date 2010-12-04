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

  def self.to_s
    Host.new(Environment.new(nil, true)).to_s rescue ''
  end

  attr_accessor :arch, :vendor, :kernel, :misc

  def initialize (data)
    @arch   = data[:ARCH]
    @vendor = data[:VENDOR]
    @kernel = data[:KERNEL]
    @misc   = data[:MISC]

    case @arch
      when 'core2'; @arch = 'x86_64'
      when 'amd64'; @arch = 'x86_64'
      when 'x86';   @arch = 'i686'
    end

    case @kernel
      when 'windows'; @kernel = 'cygwin'
      when 'mac';     @kernel = 'darwin'
      when 'linux';   @misc   = 'gnu' if !@misc
    end
  end

  def == (value)
    self.to_s == value.to_s
  end

  def to_s
    "#{arch}#{"-#{vendor}" if vendor}-#{kernel}#{"-#{misc}" if misc}"
  end
end

end
