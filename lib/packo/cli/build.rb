# encoding: utf-8
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

require 'packo'
require 'packo/cli'
require 'packo/do/build'

module Packo; module CLI

class Build < Thor
  include Thor::Actions

  class_option :help, type: :boolean, desc: 'Show help usage'

  desc 'package PACKAGE... [OPTIONS]', 'Create packages of the matching names'
  method_option :output,     type: :string,  default: '.',   aliases: '-o', desc: 'The directory where to save packages'
  method_option :wipe,       type: :boolean, default: false, aliases: '-w', desc: 'Wipes the package directory before building it'
  method_option :ask,        type: :boolean, default: false, aliases: '-a', desc: 'Prompt the user if he want to continue building or not'
  method_option :nodeps,     type: :boolean, default: false, aliases: '-N', desc: 'Ignore blockers and dependencies'
  method_option :repository, type: :string,                  aliases: '-r', desc: 'Set a specific source repository'
  def package (*packages)
    output = File.realpath(options[:output])

    packages.map {|package|
      begin
        package = Do::Build.package(package, options)

        if package.parent.nil?
          CLI.warn "The package #{package} does not have a parent"
        end

        package
      rescue Do::Build::Exceptions::IncompleteEnvironment => e
      rescue Do::Build::Exceptions::PackageNotFound => e
      rescue Do::Build::Exceptions::MultiplePackages => e
        CLI.fatal e.message

        exit 2
      rescue Package::Tags::Expression::EvaluationError => e
        CLI.fatal e.message

        exit 3
      rescue LoadError
        CLI.warn "The package #{package} could not be instantiated"

        nil
      end
    }.compact.each {|package|
      CLI.info "Building #{package}"

      begin
        Do::Build.build(package, options) {|stage|
          CLI.info "Executing #{stage.name}"
        }

        CLI.info "Succesfully built #{package}"
      rescue Exception => e
        CLI.fatal "Failed to build #{package}"
        CLI.fatal e.message

        Packo.debug e
      end
    }
  rescue Exception => e
    Packo.debug e

    exit 99
  end

  desc 'command PACKAGE COMMAND', 'Build package from an executed command'
  method_option :bump,    type: :boolean, default: true,  aliases: '-b', desc: 'Bump revision when creating a package from command if package is installed'
  method_option :inspect, type: :boolean, default: false, aliases: '-i', desc: 'Inspect the list of files that will be included in the package in EDITOR'
  def command (package, command)
    if Packo.protected?
      CLI.warn "`packo build -x` may not work properly, try with `packo-build -x` if it fails.\n\n"
    end

    begin
      Do::Build.command(Package.parse(package), command, options)

      CLI.info "Succesfully built #{package}"
    rescue Do::Build::Exceptions::InvalidName => e
      CLI.fatal e.message

      exit 40
    rescue Exception => e
      CLI.fatal "Failed to build #{package}"
      CLI.fatal e.message

      Packo.debug e
    end
  end

  desc 'clean PACKAGE... [OPTIONS]', 'Clean packages'
  method_option :repository, type: :string, aliases: '-r', desc: 'Set a specific source repository'
  def clean (*packages)
    packages.map {|package|
      begin
        package = Do::Build.package(package, options)

        if package.parent.nil?
          CLI.warn "The package #{package} does not have a parent"
        end

        package
      rescue Do::Build::Exceptions::IncompleteEnvironment => e
      rescue Do::Build::Exceptions::PackageNotFound => e
      rescue Do::Build::Exceptions::MultiplePackages => e
        CLI.fatal e

        exit 2
      rescue Package::Tags::Expression::EvaluationError => e
        CLI.fatal e.message

        exit 3
      rescue LoadError
        CLI.warn "The package #{package} could not be instantiated"
        nil
      end
    }.compact.each {|package|
      begin
        Do::Build.clean(package)

        CLI.info "Cleaned #{package.to_s(:name)}"
      rescue Exception => e
        CLI.fatal "Failed cleaning of #{package.to_s(:name)}"
        Packo.debug e
      end
    }
  end

  desc 'digest RBUILD...', 'Digest the given rbuilds'
  def digest (*files)
    files.each {|file|
      if !File.exists?(file)
        CLI.fatal "#{file} does not exist"
        exit 40
      end

      begin
        Do.cd(File.dirname(file)) {
          File.write('digest.xml', Do::Build.digest(file))
        }
      rescue Do::Build::Exceptions::PackageNotFound => e
      rescue Package::Tags::Expression::EvaluationError => e
        CLI.fatal e.message

        raise e
      rescue LoadError
        CLI.fatal 'Failed to load the rbuild'

        exit 41
      end
    }
  rescue Errno::EACCES
    CLI.fatal 'Try to use packo-build instead.'
  rescue Exception => e
    Packo.debug e
    exit 99
  end

  desc 'manifest PACKAGE [OPTIONS]', 'Output the manifest of the given package'
  method_option :repository, type: :string, aliases: '-r', desc: 'Set a specific source repository'
  def manifest (package)
    begin  
      Do::Build.manifest(package)
    rescue Do::Build::Exceptions::PackageNotFound
      CLI.fatal 'Package could not be instantiated'

      exit 23
    end
  end

  desc 'info FILE', 'Get informations about an rbuild'
  def info (file)
    if File.basename(file).match(/.*?-\d/)
      package = Packo.loadPackage(File.dirname(file), Package.parse(File.basename(file).sub(/\.rbuild$/, '')))
    else
      package = Packo.loadPackage(file)
    end

    print package.name.bold
    print "-#{package.version.to_s.red}"
    print " {#{package.revision.yellow.bold}}" if package.revision > 0
    print " (#{package.slot.blue.bold})" if package.slot
    print " [#{package.tags.join(' ').magenta}]"
    print "\n"

    puts "    #{'Description'.green}: #{package.description}"
    puts "    #{'Homepage'.green}:    #{package.homepage}"
    puts "    #{'License'.green}:     #{package.license}"
    puts "    #{'Maintainer'.green}:  #{package.maintainer || 'nobody'}"

    flavor = []
    package.flavor.each {|f|
      next if [:vanilla, :documentation, :headers, :debug].member?(f.name)

      flavor << f
    }

    features = []
    package.features.each {|f|
      features << f
    }

    length = (flavor + features).map {|f|
      f.name.length
    }.max

    if flavor.length > 0
      print "    #{'Flavor'.green}:      "

      flavor.each {|element|
        if element.enabled
          print "#{element.name.to_s.white.bold}#{System.env[:NO_COLORS] ? '!' : ''}"
        else
          print element.name.to_s.black.bold
        end

        print "#{' ' * (4 + length - element.name.length + (System.env[:NO_COLORS] && !element.enabled? ? 1 : 0))}#{element.description || '...'}"

        print "\n                   "
      }

      print "\r" if features.length > 0
    end

    if features.length > 0
      print "    #{'Features'.green}:    "

      features.each {|feature|
        if feature.enabled
          print "#{feature.name.to_s.white.bold}#{System.env[:NO_COLORS] ? '!' : ''}"
        else
          print feature.name.to_s.black.bold
        end

        print "#{' ' * (4 + length - feature.name.length + (System.env[:NO_COLORS] && !feature.enabled? ? 1 : 0))}#{feature.description || '...'}"

        print "\n                 "
      }
    end

    print "\n"
  end

  def initialize (*args)
    FileUtils.mkpath(System.env[:TMP])
    File.umask 022

    super(*args)
  end
end

end; end
