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

require 'packo/rbuild'

module Packo; class Do
  
class Build
  module Exceptions
    IncompleteEnvironment = Class.new(Exception)
    PackageNotFound       = Class.new(Exception)
    MultiplePackages      = Class.new(Exception)
    InvalidName           = Class.new(Exception)
  end

  def self.build (package, options={}, &block)
    package = self.package(package, options)

    if !System.env[:ARCH] || !System.env[:KERNEL] || !System.env[:LIBC] || !System.env[:COMPILER]
      raise Exceptions::IncompleteEnviroment.new 'You have to set ARCH, KERNEL, LIBC and COMPILER to build packages.'
    end

    output = nil
    pwd    = Dir.pwd

    System.env.sandbox(options[:env] || {}) {
      package.after :pack do |path|
        path = File.realpath(path)

        if options[:output]
          Do.cd(pwd) {
            Do.cp(path, options[:output])
          }
        end

        output = path
      end

      if (File.read("#{package.directory}/.build") rescue nil) != package.to_s(:everything) || options[:wipe]
        Build.clean(package)

        package.create!

        File.write("#{package.directory}/.build", package.to_s(:everything)) rescue nil
      end

      package.build &block
    }

    output
  end

  def self.command (package, command, options={})
    if !package.is_a?(Packo::Package)
      package = Packo::Package.parse(package.to_s)
    end

    unless package.name && package.version
      raise InvalidName.new 'You have to pass a valid package name and version, like package-0.2'
    end

    package = RBuild::Package.define(package.name, package.version) {
      tags *package.tags

      description "Built :in => `#{Dir.pwd}` with `#{command}`"
      maintainer  env[:USER]
    }

    package.avoid RBuild::Behaviors::Default

    package.clean!
    package.create!

    tmp = Tempfile.new('packo')
    dir = "#{System.env[:TMP]}/#{Process.pid}"

    tmp.write %{
      #! /bin/sh

      cd "#{Dir.pwd}"

      #{command}

      exit $?
    }

    tmp.chmod 0700
    tmp.close

    Packo.sh 'installwatch', "--logfile=#{package.tempdir}/newfiles.log", "--exclude=#{Dir.pwd}",
      "--root=#{package.workdir}", '--transl=yes', '--backup=no', tmp.path

    package.before :pack, :priority => -42 do
      files = File.new("#{tempdir}/newfiles", 'w')

      files.print File.new("#{tempdir}/newfiles.log", 'r').lines.map {|line| line.strip!
        whole, type = line.match(/^.*?\t(.*?)\t/).to_a

        case type
          when 'chmod', 'open'
            whole, file = line.match(/.*?\t.*?\t(.*?)(\t|$)/).to_a

            next if file.match(%r[^(/dev|#{Regexp.escape(Dir.pwd)}|/tmp)(/|$)])

            file

          when 'symlink'
            whole, to, file = line.match(/.*?\t.*?\t(.*?)\t(.*?)(\t|$)/).to_a

            "#{file} -> #{to}"
        end
      }.compact.uniq.sort.join("\n")

      files.close

      if options[:inspect] && STDOUT.tty? && STDIN.tty?
        Packo.sh System.env[:EDITOR] || 'vi', files.path
      end

      links = []

      File.new("#{tempdir}/newfiles", 'r').lines.each {|line|
        whole, file, link = line.match(/^(.*?)(?: -> (.*?))?$/).to_a

        FileUtils.mkpath "#{distdir}/#{File.dirname(file)}"

        if link
          links << [link, file]
        else
          FileUtils.cp "#{workdir}/TRANSL/#{file}", "#{distdir}/#{file}"
        end
      }

      links.each {|(link, file)|
        FileUtils.ln_sf link, "#{distdir}/#{file}" rescue nil
      }
    end

    package.before :pack do
      if options[:inspect] && STDOUT.tty? && STDIN.tty?
        Packo.sh System.env[:EDITOR] || 'vi', "#{directory}/manifest.xml"
      end
    end

    if options[:bump]
      require 'packo/models'

      if !Models.search_installed(package.to_s).empty?
        package.revision = Models.search_installed(package.to_s).first.revision + 1
      end
    end

    package.build
  end

  def self.clean (package, options={})
    package = self.package(package, options)

    package.clean!
  end

  def self.digest (file, options={})
    Do.cd(File.dirname(file)) {
      package = self.package(file, options)

      package.digests = {}

      package.after :fetch do |result|
        stages.stop!
        skip
      end

      Do.cd {
        package.build
      }

      data = YAML.parse_file('digest.yml').transform rescue {}

      data['packages'] ||= []

      data['packages'].delete(data['packages'].find {|pkg|
        package.version == pkg['version'] && (!package.slot || package.slot == pkg['slot'])
      })

      pkg = {}
      pkg['version'] = package.version.to_s
      pkg['slot']    = package.slot if package.slot

      pkg['features'] = package.features.to_a.map {|f|
        f.name
      }.join(' ')
      
      pkg['files'] = package.distfiles.to_a.map {|(name, file)|
        file ||= name

        Hash[
          'name'   => File.basename(file.path),
          'url'    => file.url,
          'digest' => Packo.digest(file.path)
        ]
      }

      data['packages'] << pkg

      data.to_yaml
    }
  end

  def self.manifest (package, options={})
    package = self.package(package, options)
    
    RBuild::Package::Manifest.new(package).to_s
  end

  def self.package (package, options={})
    return package if package.is_a?(RBuild::Package)

    package = package.to_s

    if !package.end_with?('.rbuild')
      require 'packo/models'

      packages = Models.search(package, options)

      names = packages.group_by {|package|
        "#{package.tags}/#{package.name}"
      }.map {|(name, package)| name}.uniq

      if names.length == 0
        raise Exceptions::PackageNotFound.new "No package matches #{package}"
      elsif names.length > 1
        raise Exceptions::MultiplePackages.new "More than one package :matches => #{package}"
      end

      package = packages.select {|pkg|
        !pkg.masked?
      }.sort {|a, b|
        a.version <=> b.version
      }.last
    end

    if package.is_a?(String)
      path    = File.dirname(File.realpath(package))
      package = Package.parse(package.sub(/\.rbuild$/, ''))
    else
      path = "#{package.repository.path}/#{package.model.data.path}"
    end

    package      = Packo.loadPackage(path, package)
    package.path = path

    package
  end
end

end; end
