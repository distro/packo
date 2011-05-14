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

require 'packo/utils'

module Packo

class Do
  def self.cd (path=nil)
    if block_given?
      tmp = Dir.pwd

      Dir.chdir(path) if path
      result = yield path
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
    files.flatten!
    files.compact!

    type = (files.first.is_a?(Symbol) ? files.shift : :f).to_s

    if type.include?('r')
      Do.dir(to)
      FileUtils.cp_r(files, to, force: type.include?('f'), preserve: true)
    else
      Do.dir(File.dirname(to))
      FileUtils.cp(files, to)
    end
  end

  def self.mv (*files, to)
    files.flatten!
    files.compact!

    if files.length == 1
      Do.dir(File.dirname(to))
      FileUtils.mv(files.first, to, force: true)
    else
      Do.dir(to)
      FileUtils.mv(files, to, force: true)
    end
  end

  def self.rm (*files)
    files.flatten!
    files.compact!

    type = (files.first.is_a?(Symbol) ? files.shift : :f).to_s

    files.each {|file|
      next unless File.exists?(file)

      case type
        when /r/
          FileUtils.rm_r(file, :force => type.include?('f'), :secure => true)

        else
          if File.directory?(file)
            Dir.delete(file) rescue nil
          else
            FileUtils.rm(file, :force => type.include?('f')) rescue nil
          end
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
      content.gsub!(regexp, sub.to_s)
    }

    File.write(file, content)
  end

  attr_reader :package

  def initialize (package)
    @package = package

    @opts     = nil
    @verbose  = true
  end

  def verbose?;     @verbose         end
  def verbose!;     @verbose = true  end
  def not_verbose!; @verbose = false end

  def root
    @root || package.distdir
  end

  def root= (path)
    FileUtils.mkpath(path)
  end

  def into (path)
    tmp, @relative = @relative, path

    Do.dir "#{root}/#{@relative}"

    yield

    @relative = tmp
  end

  def opts (value)
    tmp, @opts = @opts, value

    yield

    @opts = tmp
  end

  alias chmod opts
  alias opt opts

  def dir (path)
    FileUtils.mkpath "#{root}/#{path}", verbose: @verbose
    FileUtils.chmod @opts || 0755, "#{root}/#{path}", verbose: @verbose
  end

  def rm (*files)
    files.flatten.compact.each {|file|
      Do.rm Path.clean("#{root}/#{@relative}/#{file}")
    }
  end

  def own (user, group, *files)
    files.flatten.compact.each {|file|
      FileUtils.chown user, group, files, :verbose => @verbose
    }
  end

  def ins (*files)
    files.map {|file|
      file.is_a?(Array) ? [file] : Dir.glob(file)
    }.flatten(1).each {|(file, name)|
      path = Path.clean("#{root}/#{@relative || 'usr'}/#{File.basename(name || file)}")

      FileUtils.cp_r file, path, preserve: true, verbose: @verbose
      FileUtils.chmod @opts || 0644, path, verbose: @verbose
    }
  end

  def bin (*bins)
    bins.map {|bin|
      bin.is_a?(Array) ? [bin] : Dir.glob(bin)
    }.flatten(1).each {|(file, name)|
      path = Path.clean("#{root}/#{@relative || '/'}/bin/#{File.basename(name || file)}")

      FileUtils.mkpath File.dirname(path)
      FileUtils.cp_r file, path, preserve: true, verbose: @verbose
      FileUtils.chmod @opts || 0755, path, verbose: @verbose
    }
  end

  def sbin (*sbins)
    sbins.map {|sbin|
      sbin.is_a?(Array) ? [sbin] : Dir.glob(sbin)
    }.flatten(1).each {|(file, name)|
      path = Path.clean("#{root}/#{@relative || '/'}/sbin/#{File.basename(name || file)}")

      FileUtils.mkpath File.dirname(path)
      FileUtils.cp_r file, path, preserve: true, verbose: @verbose
      FileUtils.chmod @opts || 0755, path, verbose: @verbose
    }
  end

  def lib (*libs)
    libs.map {|lib|
      lib.is_a?(Array) ? [lib] : Dir.glob(lib)
    }.flatten(1).each {|(file, name)|
      path = Path.clean("#{root}/#{@relative || '/usr'}/lib/#{File.basename(name || file)}")

      FileUtils.mkpath File.dirname(path)
      FileUtils.cp_r file, path, preserve: true, verbose: @verbose
      FileUtils.chmod @opts || (file.match(/\.a(\.|$)/) ? 0644 : 0755), path, verbose: @verbose
    }
  end

  def doc (*docs)
    into("/usr/share/doc/#{package.name}-#{package.version}") {
      docs.map {|doc|
        doc.is_a?(Array) ? [doc] : Dir.glob(doc)
      }.flatten(1).each {|(file, name)|
        path = "#{root}/#{@relative}/#{File.basename(name || file)}"

        FileUtils.cp_r file, path, preserve: true, verbose: @verbose
        FileUtils.chmod @opts || 0644, path, verbose: @verbose
      }
    }
  end

  def html (*htmls)
    into("/usr/share/doc/#{package.name}-#{package.version}/html") {
      htmls.map {|html|
        html.is_a?(Array) ? [html] : Dir.glob(html)
      }.flatten(1).each {|(file, name)|
        path = "#{root}/#{@relative}/#{File.basename(name || file)}"

        FileUtils.cp_r file, path, preserve: true, verbose: @verbose
        FileUtils.chmod @opts || 0644, path, verbose: @verbose
      }
    }
  end

  def man (*mans)
    into("/usr/share/man/man#{man[-1]}") {
      mans.map {|man|
        man.is_a?(Array) ? [man] : Dir.glob(man)
      }.flatten(1).each {|(file, name)|
        path = "#{root}/#{@relative}/#{File.basename(name || file)}"

        FileUtils.cp_r file, path, preserve: true, verbose: @verbose
        FileUtils.chmod @opts || 0644, path, verbose: @verbose
      }
    }
  end

  def info (*infos)
    into("/usr/share/info/#{info[-1]}") {
      infos.map {|info|
        info.is_a?(Array) ? [info] : Dir.glob(info)
      }.flatten(1).each {|(file, name)|
        path = "#{root}/#{@relative}/#{File.basename(name || file)}"

        FileUtils.cp_r file, path, preserve: true, verbose: @verbose
        Packo.sh 'gzip', '-9', path, silent: !@verbose rescue nil
        FileUtils.chmod @opts || 0644, path, verbose: @verbose
      }
    }
  end

  def sym (link, to)
    path = Path.clean("#{root}/#{@relative}/#{to}")

    FileUtils.mkpath File.dirname(path)
    FileUtils.ln_sf link, path, verbose: @verbose
  end

  def hard (link, to)
    path = Path.clean("#{root}/#{@relative}/#{to}")

    FileUtils.mkpath File.dirname(path) 
    FileUtils.ln_f link, path, verbose: @verbose
  end
end

end
