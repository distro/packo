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

class Do
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

  def self.dir (path)
    FileUtils.mkpath path rescue nil
  end

  def self.touch (*path)
    FileUtils.touch(path) rescue nil
  end

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

  def self.sed (file, *seds)
    content = File.read(file)

    seds.each {|(regexp, sub)|
      content.gsub!(regexp, sub || '')
    }

    File.write(file, content)
  end

  attr_reader :package

  def initialize (package)
    @package = package

    @relative = '/usr'
    @opts     = nil
  end

  def root
    "#{@root ? @root : package.distdir}/#{@relative}".gsub(%r{/*/}, '/')
  end

  def root= (path)
    FileUtils.mkpath(path)
  end

  def into (path)
    tmp, @relative = @relative, path

    Do.dir root if root != "/"
    yield

    @relative = tmp
  end

  def opts (value)
    tmp, @opts = @opts, value
    yield
    @opts = tmp
  end

  def ins (*files)
    files.map {|file| Dir.glob(file)}.flatten.each {|file|
      FileUtils.cp    file, "#{root}/#{File.basename(file)}"
      FileUtils.chmod @opts, "#{root}/#{File.basename(file)}"
    }
  end

  def dir (path)
    FileUtils.mkpath("#{root}/#{path}")
    FileUtils.chmod @opts || 0755, "#{root}/#{path}"
  end

  def bin (*bins)
    FileUtils.mkpath "#{root}/bin"

    bins.map {|bin| Dir.glob(bin)}.flatten.each {|bin|
      FileUtils.cp    bin, "#{root}/bin/#{File.basename(bin)}"
      FileUtils.chmod @opts || 0755, "#{root}/bin/#{File.basename(bin)}"
    }
  end

  def sbin (*sbins)
    FileUtils.mkpath "#{root}/sbin"

    sbins.map {|sbin| Dir.glob(sbin)}.flatten.each {|sbin|
      FileUtils.cp    sbin, "#{root}/sbin/#{File.basename(sbin)}"
      FileUtils.chmod @opts || 0755, "#{root}/sbin/#{File.basename(sbin)}"
    }
  end

  def lib (*libs)
     FileUtils.mkpath "#{root}/lib"

    libs.map {|lib| Dir.glob(lib)}.flatten.each {|lib|
      FileUtils.cp    lib, "#{root}/lib/#{File.basename(lib)}"
      FileUtils.chmod @opts || (lib.match(/\.a(\.|$)/) ? 0644 : 0755), "#{root}/lib/#{File.basename(lib)}" rescue nil
    }
  end
  
  def doc (*docs)
    into("/usr/share/doc/#{package.name}-#{package.version}") {
      docs.map {|doc| Dir.glob(doc)}.flatten.each {|doc|
        FileUtils.cp    doc, "#{root}/#{File.basename(doc)}"
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(doc)}"
      }
    }
  end

  def html (*htmls)
    into("/usr/share/doc/#{package.name}-#{package.version}/html") {
      htmls.map {|html| Dir.glob(html)}.flatten.each {|html|
        FileUtils.cp    html, "#{root}/#{File.basename(html)}"
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(html)}"
      }
    }
  end

  def man (*mans)
    mans.map {|man| Dir.glob(man)}.flatten.each {|man|
      into("/usr/share/man/man#{man[-1]}") {
        FileUtils.cp    man, "#{root}/#{File.basename(man)}"
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(man)}"
      }
    }
  end

  def info (*infos)
    infos.map {|info| Dir.glob(info)}.flatten.each {|info|
      into("/usr/share/info/#{info[-1]}") {
        FileUtils.cp    info, "#{root}/#{File.basename(info)}"
        Packo.sh 'gzip', '-9', "#{root}/#{File.basename(info)}", :silent => true
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(info)}"
      }
    }
  end

  def sym (link, to)
    FileUtils.mkpath "#{root}/#{File.dirname(to)}"
    FileUtils.ln_sf link, "#{root}/#{to}"
  end

  def hard (link, to)
    FileUtils.mkpath "#{root}/#{File.dirname(to)}"
    FileUtils.ln_f link, "#{root}/#{to}"
  end

  def own (user, group, *files)
    infos.map {|info| Dir.glob(info)}.flatten.each {|info|
      into("/usr/share/info/#{info[-1]}") {
        FileUtils.cp    info, "#{root}/#{File.basename(info)}"
        Packo.sh 'gzip', '-9', "#{root}/#{File.basename(info)}", :silent => true
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(info)}"
      }
    }
  end

  # TODO: wrappers
end

end; end
