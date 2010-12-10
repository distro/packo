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
  @@into = nil

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
      FileUtils.cp_r file, @@into
    else
      FileUtils.cp file, @@into
    end
  end

  def self.bin (*binaries)
    binaries.map {|binary| Dir.glob(binary)}.flatten.each {|binary|
      begin
        FileUtils.cp    binary, "#{@@into}/#{File.basename(binary)}", :preserve => true
        FileUtils.chmod 0755,   "#{@@into}/#{File.basename(binary)}"
      rescue Exception => e
        Packo.debug e
      end
    }
  end

  def self.man (*mans)
    mans.map {|man| Dir.glob(man)}.flatten.each {|man|
      begin
        FileUtils.cp    man,  "#{@@into}/#{File.basename(man)}", :preserve => true
        FileUtils.chmod 0644, "#{@@into}/#{File.basename(man)}"
      rescue Exception => e
        Packo.debug e
      end
    }
  end

  def self.doc (*docs)
    docs.map {|doc| Dir.glob(doc)}.flatten.each {|doc|
      begin
        FileUtils.cp    doc,  "#{@@into}/#{File.basename(doc)}", :preserve => true
        FileUtils.chmod 0644, "#{@@into}/#{File.basename(doc)}"
      rescue Exception => e
        Packo.debug e
      end
    }
  end

  def self.sym (to, link)
    FileUtils.ln_sf to, link.start_with?('/') ? link : "#{@@into}/#{link}"
  end

  def self.sed (file, *seds)
    content = File.read(file)

    seds.each {|(regexp, sub)|
      content.gsub!(regexp, sub || '')
    }

    File.write(file, content)
  end
end

end; end
