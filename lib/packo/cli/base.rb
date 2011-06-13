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

require 'packo/cli/thor'

require 'packo/models'
require 'packo/do/base'

module Packo; module CLI

class Base < Thor
  include Thor::Actions

  class_option :help, type: :boolean,
    desc: 'Show help usage'

  desc 'install PACKAGE... [OPTIONS]', 'Install packages'
    map '-i' => :install, '--install' => :install
    
    method_option :destination, aliases: '-d', type: :string, default: System.env[:INSTALL_PATH],
      desc: 'Set the destination where to install the package'
    
    method_option :inherit, aliases: '-I', type: :boolean, default: false,
      desc: 'Apply the passed flags to the eventual dependencies'
    
    method_option :force, aliases: '-f', type: :boolean, default: false,
      desc: 'Force installation when something minor goes wrong'
    
    method_option :ignore, aliases: '-x', type: :boolean, default: false,
      desc: 'Ignore the installation and do not add the package to the database'
    
    method_option :nodeps, aliases: '-N', type: :boolean, default: false,
      desc: 'Ignore dependencies'
    
    method_option :depsonly, aliases: '-D', type: :boolean, default: false,
      desc: 'Install only dependencies'
    
    method_option :repository, aliases: '-r', type: :string,
      desc: 'Set a specific repository'

  def install (*names)
  end

  desc 'uninstall PACKAGE... [OPTIONS]', 'Uninstall packages'
    map '-C' => :uninstall, '-R' => :uninstall, 'remove' => :uninstall
    
    method_option :force, aliases: '-f', type: :boolean, default: false,
      desc: 'Force installation when something minor goes wrong'

  def uninstall (*names)
  end

  desc 'update [PACKAGE...] [OPTIONS]', 'Update installed packages'
    map '-U' => :update, '--update' => :update
    
    method_option :force, aliases: '-f', type: :boolean, default: false,
      desc: 'Force installation when something minor goes wrong'
    
    method_option :repository, aliases: '-r', type: :string,
      desc: 'Set a specific repository'

  def update (*names)

  end

  desc 'search [EXPRESSION] [OPTIONS]', 'Search through installed packages'
    map '--search' => :search, '-Ss' => :search
    
    method_option :type, aliases: '-t', type: :string,
      desc: 'The repository type (binary, source, virtual)'
    
    method_option :repository, aliases: '-r', type: :string,
      desc: 'Set a specific repository'

    method_option :full, aliases: '-F', type: :boolean, default: false,
      desc: 'Include the repository that owns the package, features and flavor'

  def search (expression='')
    Models.search_installed(expression, options).group_by {|package|
      "#{package.tags}/#{package.name}"
    }.sort.each {|(name, packages)|
      if options[:full]
        packages.group_by {|package|
          "#{package.repository.type}/#{package.repository.name}" rescue nil
        }.each {|name, packages|
          packages.group_by {|package|
            "#{package.features} #{package.flavor}"
          }.each {|name, packages|
            print "#{"#{packages.first.tags}/" unless packages.first.tags.empty?}#{packages.first.name.bold}"

            print ' ('
            print packages.sort {|a, b|
              a.version <=> b.version
            }.map {|package|
              "#{package.version.to_s.red}" + (package.slot ? "%#{package.slot.to_s.blue.bold}" : '')
            }.join(', ')
            print ')'

            print " [#{packages.first.features}]" unless packages.first.features.empty?
            print " {#{packages.first.flavor}}"   unless packages.first.flavor.empty?

            print " <#{"#{packages.first.repository.type}/#{packages.first.repository.name}".black.bold}>" if packages.first.repository
          }
        }
      else
        print "#{packages.first.tags}/#{packages.first.name.bold} ("

        print packages.sort {|a, b|
          a.version <=> b.version
        }.map {|package|
          "#{package.version.to_s.red}" + (package.slot ? "%#{package.slot.to_s.blue.bold}" : '')
        }.join(', ')

        print ")"
      end

      print "\n"
    }
  end

  desc 'info [EXPRESSION] [OPTIONS]', 'Search through installed packages and returns detailed informations about them'
    map '--info' => :info
    
    method_option :type, aliases: '-t', type: :string,
      desc: 'The repository type (binary, source, virtual)'
    
    method_option :repository, aliases: '-r', type: :string,
      desc: 'Set a specific repository'

  def info (expression='')
    Models.search_installed(expression, options[:repository], options[:type]).each {|package|
      print package.name.bold
      print "-#{package.version.to_s.red}"
      print " {#{package.revision.yellow.bold}}" if package.revision > 0
      print " (#{package.slot.to_s.blue.bold})" if package.slot
      print " [#{package.tags.join(' ').magenta}]" if !package.tags.empty?
      print "\n"

      puts "    #{'Description'.green}: #{package.description}"      if package.description
      puts "    #{'Homepage'.green}:    #{package.homepage}"         if package.homepage
      puts "    #{'License'.green}:     #{package.license}"          if package.license
      puts "    #{'Maintainer'.green}:  #{package.model.maintainer}" if package.maintainer
      puts "    #{'Flavor'.green}:      #{package.flavor}"           if package.flavor
      puts "    #{'Features'.green}:    #{package.features}"         if package.features

      print "\n"
    }
  end

  no_tasks {
    def initialize (*args)
      FileUtils.mkpath(System.env[:TMP])
      File.umask 022

      super(*args)
    end
  }
end

end; end
