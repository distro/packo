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
    FileUtils.mkpath(path) rescue nil
  end

  def self.cd (path)
    if block_given?
      tmp = Dir.pwd

      Dir.chdir(path)
      yield
      Dir.chdir(tmp)
    else
      Dir.chdir(path) rescue false
    end
  end

  def self.touch (*path)
    FileUtils.touch(path) rescue nil
  end

  def self.into (path)
    Do.dir(@@into = path)
  end

  def self.ins (file, options={})
    if options[:recursive]
      File.cp_r file, @@into
    else
      File.cp file, @@into
    end
  end

  def self.sym (link, to)
    FileUtils.ln_sf link, to.start_with?('/') ? to : "#{@@into}/#{to}"
  end
end

end; end
