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
  module Exceptions
    Unsupported = Class.new(Exception)
  end

  class Manifest
    def self.open (path)
      self.parse(File.read(path))
    end

    attr_reader :package

    def initialize (package)
      @package = package
    end

    def save (to, options={})
      File.write(to, to_s(options))
    end
  end

  class Format
    attr_reader :type

    def initialize (type, &block)
      @type = type

      self.instance_eval(&block)
    end

    def pack (*args, &block)
      if block
        @pack = block
      else
        @pack.call(*args)
      end
    end

    def unpack (*args, &block)
      if block
        @unpack = block
      else
        @unpack.call(*args)
      end
    end

    def manifest (&block)
      if block
        @manifest = Class.new(Manifest, &block)
      else
        @manifest
      end
    end
  end

  @@formats = []

  def self.register (type, &block)
    @@formats << Format.new(type, &block)

    @@formats.sort! {|a, b|
      a.type <=> b.type
    }
  end

  def self.supports? (name)
    !!@@formats[name.to_s]
  end

  def self.pack (package, to=nil)
    format = @@formats.find {|format|
      (to || '.pko').end_with?(format.type)
    } or raise Exceptions::Unsupported.new('Package fromat unsupported')

    format.pack(package, to)
  end

  def self.unpack (package, to=nil)
    format = @@formats.find {|format|
      (to || '.pko').end_with?(format.type)
    } or raise Exceptions::Unsupported.new('Package fromat unsupported')

    format.unpack(package, to)
  end

  def self.manifest (package, to=nil)
    format = @@formats.find {|format|
      (to || '.pko').end_with?(format.type)
    } or raise Exceptions::Unsupported.new('Package fromat unsupported')

    format.manifest
  end

  def initialize (package)
    super(package)

    package.stages.add :pack, self.method(:pack), at: :end, strict: true
  end

  def finalize
    package.stages.delete :pack, self.method(:pack)
  end

  def pack
    package.callbacks(:pack).do {
      package.filesystem.files.save(package.distdir)

      Packager.pack(package, "#{package.to_s :package}.#{package.extension || '.pko'}")
    }
  end
end

end; end; end
