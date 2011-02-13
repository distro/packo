# encoding: utf-8
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

require 'nokogiri'
require 'digest/sha1'

require 'packo'
require 'packo/rbuild'

module Packo; module CLI

class Build < Thor
  include Thor::Actions

  class_option :help, :type => :boolean, :desc => 'Show help usage'

  desc 'package PACKAGE... [OPTIONS]', 'Create packages of the matching names'
  method_option :output,     :type => :string,  :default => System.env[:TMP], :aliases => '-o', :desc => 'The directory where to save packages'
  method_option :wipe,       :type => :boolean, :default => false,            :aliases => '-w', :desc => 'Wipes the package directory before building it'
  method_option :ask,        :type => :boolean, :default => false,            :aliases => '-a', :desc => 'Prompt the user if he want to continue building or not'
  method_option :repository, :type => :string,                                :aliases => '-r', :desc => 'Set a specific source repository'
  def package (*packages)
    Environment.new {|env|
      if !env[:ARCH] || !env[:KERNEL] || !env[:LIBC] || !env[:COMPILER]
        CLI.fatal 'You have to set ARCH, KERNEL, LIBC and COMPILER to build packages.'
        exit 1
      end
    }

    packages.map {|package|
      if package.end_with?('.rbuild')
        package
      else
        require 'packo/models'

        packages = Models.search(package, options[:repository])
  
        names = packages.group_by {|package|
          "#{package.tags}/#{package.name}"
        }.map {|(name, package)| name}.uniq
  
        if names.length == 0
          CLI.fatal "No package matches #{package}"

          exit 10
        elsif names.length > 1
          CLI.fatal "More than one package matches: #{package}"
  
          names.each {|name|
            puts "    #{name}"
          }
          
          exit 11
        end
  
        packages.sort {|a, b|
          a.version <=> b.version
        }.last
      end
    }.each {|package|
      if package.is_a?(String)
        path    = File.dirname(File.realpath(package))
        package = Package.parse(package.sub(/\.rbuild$/, ''))
      else
        path = "#{package.repository.path}/#{package.model.data.path}"
      end

      manifest = Nokogiri::XML.parse(File.read("#{path}/digest.xml"))

      files = {}
      manifest.xpath('//files/file').each {|e|
        files[e['name']] = e.text
      }

      begin; package = Packo.loadPackage(path, package); rescue LoadError; end

      if !package
        CLI.fatal 'The package could not be instantiated'
        exit 12
      end

      if package.parent.nil?
         CLI.warn 'The package does not have a parent'
      end

      package.path = path

      CLI.info "Building #{package}"

      output = File.realpath(options[:output])

      package.after :pack do |path|
        FileUtils.cp path, output, :preserve => true
      end

      if (File.read("#{package.directory}/.build") rescue nil) != package.to_s(:everything) || options[:wipe]
        CLI.info "Cleaning #{package} because something changed."

        clean("#{package.to_s(:name)}-#{package.version}")

        package.create!

        begin
          File.write("#{package.directory}/.build", package.to_s(:everything))
        rescue; end
      end

      begin
        package.build {|stage|
          CLI.info "Executing #{stage.name}"
        }

        CLI.info "Succesfully built #{package}"
      rescue Exception => e
        CLI.fatal "Failed to build #{package}"
        CLI.fatal e.message
        Packo.debug e
      end
    }
  end

  desc 'clean PACKAGE... [OPTIONS]', 'Clean packages'
  method_option :repository, :type => :string, :aliases => '-r', :desc => 'Set a specific source repository'
  def clean (*packages)
    packages.map {|package|
      if package.end_with?('.rbuild')
        package
      else
        require 'packo/models'

        packages = Models.search(package, options[:repository])

        if (multiple = packages.uniq).length > 1
          CLI.fatal 'Multiple packages with the same name, be more precise.'
          exit 2
        end

        packages.last
      end
    }.compact.each {|package|
      if package.is_a?(String)
        path    = File.dirname(File.realpath(package))
        package = Package.parse(package.sub(/\.rbuild$/, ''))
      else
        path = "#{package.repository.path}/#{package.model.data.path}"
      end

      begin
        package = Packo.loadPackage(path, package)
        package.clean!

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

      Dir.chdir(File.dirname(file))

      begin
        if File.basename(package).match(/.*?-\d/)
          package = Packo.loadPackage(File.dirname(package), Package.parse(File.basename(package).sub(/\.rbuild$/, '')))
        else
          package = Packo.loadPackage(package)
        end
      rescue LoadError
        CLI.fatal 'Failed to load the rbuild'
        exit 41
      end

      if !package
        CLI.fatal "Couldn't instantiate the package."
        exit 42
      end

      package.after :fetch do |result|
        package.stages.stop!

        throw :halt
      end
    
      package.build

      original = Nokogiri::XML.parse(File.read('digest.xml')) rescue nil
  
      builder = Nokogiri::XML::Builder.new {|xml|
        xml.digest(:version => '1.0') {
          xml.build(:version => package.version, :slot => package.slot) {
            xml.features package.features.to_a.map {|f| f.name}.join(' ')

            xml.files {
              package.distfiles.each {|file|
                xml.file({ :name => File.basename(file) }, Digest::SHA1.hexdigest(File.read(file)))
              }
            }
          }

          if original
            original.xpath('//build').each {|build|
              if build['version'] != package.version.to_s && ((build['slot'].empty? && !package.slot) || build['slot'] != package.slot.to_s)
                xml.doc.root.add_child(build)
              end
            }
          end
        }
      }

      File.write('digest.xml', builder.to_xml(:indent => 4))
    }
  rescue Errno::EACCES
    CLI.fatal 'Try to use packo-build instead.'
  end

  desc 'manifest PACKAGE [OPTIONS]', 'Output the manifest of the given package'
  method_option :repository, :type => :string, :aliases => '-r', :desc => 'Set a specific source repository'
  def manifest (package)
    if package.end_with?('.rbuild')
      if File.basename(package).match(/.*?-\d/)
        package = Packo.loadPackage(File.dirname(package), Package.parse(File.basename(package).sub(/\.rbuild$/, '')))
      else
        package = Packo.loadPackage(package)
      end
    else
      require 'packo/models'

      tmp = Models.search(package, options[:repository])

      if tmp.empty?
        CLI.fatal 'Package not found'
        exit 21
      end

      if (multiple = tmp.uniq).length > 1
        CLI.fatal 'Multiple packages with the same name, be more precise.'
        exit 22
      end

      package = Packo.loadPackage("#{tmp.last.repository.path}/#{tmp.last.model.data.path}", tmp.last)
    end

    if package
      puts RBuild::Package::Manifest.new(package).to_s
    else
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
