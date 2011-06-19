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

require 'find'

module Packo; module RBuild; module Modules; module Helpers

class Python < Module
  module Functions
    def fix_shebang (file, version=nil)
      unless File.file?(file) || File.symlink?(file)
        raise ArgumentError.new("#{file} isn't a file")
      end

      return false unless (content = File.read(file)).match(/^#\s*!.*?python/)

      File.write(file, content.sub(/^#\s*!.*?\n/, "#! /usr/bin/env python#{version}\n"))

      true
    end

    def fix_shebangs (directory, version=nil)
      if File.directory?(directory)
        Find.find(directory) {|path|
          next unless File.file?(path)

          fix_shebang(path, version)
        }
      else
        fix_shebang(directory)
      end
    end
  end

  def initialize (package)
    super(package)

    package.py = Class.new(Module::Helper) {
      include Functions
    }.new(package)
  end

  def finalize
    package.py = nil
  end
end

end; end; end; end
