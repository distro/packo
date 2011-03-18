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

module Packo

class Do
  def self.cd (path=nil)
    if block_given?
      tmp = Dir.pwd

      Dir.chdir(path) if path
      result = yield
      Dir.chdir(tmp)
      result
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

  def self.cp (*files, to)
    if files.length == 1
      Do.dir(File.dirname(to))
      FileUtils.cp_r(files.first, to)
    else
      Do.dir(to)
      FileUtils.cp_r(files, to)
    end
  end

  def self.mv (*files, to)
    if files.length == 1
      Do.dir(File.dirname(to))
      FileUtils.mv(files.first, to, :force => true)
    else
      Do.dir(to)
      FileUtils.mv(files, to, :force => true)
    end
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

  def self.clean (*path)
    path.each {|dir|
      begin
        ndel = Dir.glob("#{dir}/**/", File::FNM_DOTMATCH).count do |d|
          begin; Dir.rmdir d; rescue SystemCallError; end
        end
      end while ndel > 0
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
    @verbose  = true
  end

  def verbose?;     @verbose         end
  def verbose!;     @verbose = true  end
  def not_verbose!; @verbose = false end

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
      FileUtils.cp_r file, "#{root}/#{File.basename(file)}", :preserve => true, :verbose => @verbose
      FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(file)}", :verbose => @verbose
    }
  end

  def dir (path)
    FileUtils.mkpath "#{root}/#{path}", :verbose => @verbose
    FileUtils.chmod @opts || 0755, "#{root}/#{path}", :verbose => @verbose
  end

  def bin (*bins)
    FileUtils.mkpath "#{root}/bin"

    bins.map {|bin| Dir.glob(bin)}.flatten.each {|(file, name)|
      FileUtils.cp_r file, "#{root}/bin/#{File.basename(name || file)}", :preserve => true, :verbose => @verbose
      FileUtils.chmod @opts || 0755, "#{root}/bin/#{File.basename(name || file)}", :verbose => @verbose
    }
  end

  def sbin (*sbins)
    FileUtils.mkpath "#{root}/sbin"

    sbins.map {|sbin| Dir.glob(sbin)}.flatten.each {|(file, name)|
      FileUtils.cp_r file, "#{root}/sbin/#{File.basename(name || file)}", :preserve => true, :verbose => @verbose
      FileUtils.chmod @opts || 0755, "#{root}/sbin/#{File.basename(name || file)}", :verbose => @verbose
    }
  end

  def lib (*libs)
     FileUtils.mkpath "#{root}/lib"

    libs.map {|lib| Dir.glob(lib)}.flatten.each {|(file, name)|
      FileUtils.cp_r file, "#{root}/lib/#{File.basename(name || file)}", :preserve => true, :verbose => @verbose
      FileUtils.chmod @opts || (file.match(/\.a(\.|$)/) ? 0644 : 0755), "#{root}/lib/#{File.basename(name || file)}", :verbose => @verbose
    }
  end

  def doc (*docs)
    into("/usr/share/doc/#{package.name}-#{package.version}") {
      docs.map {|doc| Dir.glob(doc)}.flatten.each {|(file, name)|
        FileUtils.cp_r file, "#{root}/#{File.basename(name || file)}", :preserve => true, :verbose => @verbose
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(name || file)}", :verbose => @verbose
      }
    }
  end

  def html (*htmls)
    into("/usr/share/doc/#{package.name}-#{package.version}/html") {
      htmls.map {|html| Dir.glob(html)}.flatten.each {|(file, name)|
        FileUtils.cp_r file, "#{root}/#{File.basename(name || file)}", :preserve => true, :verbose => @verbose
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(name || file)}", :verbose => @verbose
      }
    }
  end

  def man (*mans)
    mans.map {|man| Dir.glob(man)}.flatten.each {|man|
      into("/usr/share/man/man#{man[-1]}") {
        FileUtils.cp_r man, "#{root}/#{File.basename(man)}", :preserve => true, :verbose => @verbose
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(man)}", :verbose => @verbose
      }
    }
  end

  def info (*infos)
    infos.map {|info| Dir.glob(info)}.flatten.each {|info|
      into("/usr/share/info/#{info[-1]}") {
        FileUtils.cp_r info, "#{root}/#{File.basename(info)}", :preserve => true, :verbose => @verbose
        Packo.sh 'gzip', '-9', "#{root}/#{File.basename(info)}", :silent => !@verbose rescue nil
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(info)}", :verbose => @verbose
      }
    }
  end

  def sym (link, to)
    FileUtils.mkpath "#{root}/#{File.dirname(to)}"
    FileUtils.ln_sf link, "#{root}/#{to}", :verbose => @verbose
  end

  def hard (link, to)
    FileUtils.mkpath "#{root}/#{File.dirname(to)}"
    FileUtils.ln_f link, "#{root}/#{to}", :verbose => @verbose
  end

  def own (user, group, *files)
    infos.map {|info| Dir.glob(info)}.flatten.each {|info|
      into("/usr/share/info/#{info[-1]}") {
        FileUtils.cp_r info, "#{root}/#{File.basename(info)}", :preserve => true, :verbose => @verbose
        Packo.sh 'gzip', '-9', "#{root}/#{File.basename(info)}", :silent => !@verbose rescue nil
        FileUtils.chmod @opts || 0644, "#{root}/#{File.basename(info)}", :verbose => @verbose
      }
    }
  end

  # TODO: wrappers
end

end
