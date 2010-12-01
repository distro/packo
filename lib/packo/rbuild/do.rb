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

require 'fileutils'

module Packo; module RBuild;

module Do
  @@paths = []

  def self.rm (*path)
    path.each {|path|
      next unless File.exists?(path)

      if File.directory?(path)
        Dir.delete(path) rescue nil
      else
        FileUtils.rm_f(path) rescue nil
      end
    }
  end

  def self.dir (path)
    FileUtils.mkpath(path) rescue false
  end

  def self.cd (path)
    Dir.chdir(path) rescue false
  end

  def self.touch (*path)
    FileUtils.touch(path) rescue nil
  end

  def self.pushd (path)
    @@paths.push(Dir.pwd)
    Dir.chdir(path)
  end

  def self.popd
    Dir.chdir(@@paths.pop)
  end
end

end; end
