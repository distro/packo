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

module Packo; module RBuild; module Modules

class Packager < Module
  @@formats = {}

  def self.register (of, type, &block)
    (@@formats[type] ||= {})[of] = block
  end

  def self.pack (package, to=nil)
    block = @@formats.find {|extension, block|
      (to || '.pko').end_with?(extension)
    }.last[:pack] rescue nil

    if block
      block.call(package, to)
    else
      Packo.debug 'Package format unsupported'
    end
  end

  def self.unpack (package, to=nil)
    block = @@formats.find {|extension, block|
      (to || '.pko').end_with?(extension)
    }.last[:unpack] rescue nil

    if block
      block.call(package, to)
    else
      Packo.debug 'Package format unsupported'
    end
  end

  def initialize (package)
    super(package)

    package.stages.add :pack, self.method(:pack), at: :end, strict: true
  end

  def finalize
    package.stages.delete :pack, self.method(:pack)
  end

  def pack
    package.stages.callbacks(:pack).do {
      Packager.pack(package)
    }
  end
end

end; end; end
