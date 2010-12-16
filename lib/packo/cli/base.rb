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

require 'packo/cli/common'

module Packo; module CLI

class Base < Thor
  include Thor::Actions

  class_option :help, :type => :boolean, :desc => 'Show help usage'

  desc 'version', 'Show current version'
  map '-v' => :version, '--version' => :version
  def version
    puts "packø v. #{Packo.version}"
  end

  desc 'install PACKAGE...', 'Install packages'
  map '-i' => :install, '--install' => :install
  method_option :destination, :type => :string,  :aliases => '-d', :default => '/',   :desc => 'Set the destination where to install the package'
  method_option :inherit,     :type => :boolean, :aliases => '-I', :default => false, :desc => 'Apply the passed flags to the eventual dependencies'
  method_option :force,       :type => :boolean, :aliases => '-f', :default => false, :desc => 'Force installation when something minor goes wrong'
  method_option :nodeps,      :type => :boolean, :aliases => '-N', :default => false, :desc => 'Ignore blockers and dependencies'
  method_option :depsonly,    :type => :boolean, :aliases => '-D', :default => false, :desc => 'Install only dependencies'
  method_option :repository,  :type => :string,  :aliases => '-r',                    :desc => 'Set a specific repository' 
  def install (*names)
    outside = options[:destination] != '/'
    type    = names.last.is_a?(Symbol) ? names.pop : :both

    FileUtils.mkpath options[:destination] rescue nil
    FileUtils.mkpath System.env[:SELECTORS] rescue nil

    binary = false

    if names.last === true
      manual = names.shift ? 0 : 1
    else
      manual = 1
    end

    names.each {|name|
      if File.extname(name).empty?
        packages = nil
  
        if System.env[:FLAVOR].include?('binary')
          packages = _search(name, options[:repository], :binary)
  
          if packages.empty?
            warn "#{name} could not be found in the binary repositories, looking in source repositories"
            packages = nil
          else
            binary = true
          end
        end
  
        begin
          if !packages
            packages = _search(name, options[:repository], :source)
  
            binary = false
          end
  
          names = packages.group_by {|package|
            "#{package.tags}/#{package.name}"
          }.map {|(name, package)| name}.uniq
  
          if names.length > 1
            fatal "More than one package matches: #{name}"
            names.each {|name|
              puts "    #{name}"
            }
          
            exit 10
          end
  
          package = packages.sort {|a, b|
            a.version <=> b.version
          }.last
  
          if !package
            fatal "#{name} not found"
            exit 11
          end
  
          env = Environment.new(package)
  
          _filter(package, env)
  
          if package.repository.type == :binary && !_has(package, env)
            warn 'The binary package is not available with the features you asked for, trying to build from source'
            packages = nil
            raise ArgumentError
          end
        rescue ArgumentError
          retry
        end
  
        case package.repository.type
          when :binary
            name = "#{package.tags.to_s(true)}/#{package.name}-#{package.version}"
  
            flavor = ''
            env[:FLAVOR].split(/\s+/).reject {|f| f == 'binary'}.each {|f|
              flavor << ".#{f}"
            }
            flavor[0, 1] = ''
  
            features = ''
            env[:FEATURES].split(/\s+/).each {|f|
              features << "-#{f}"
            }
            features[0, 1] = ''
  
            name << "%#{package.slot}"
            name << "+#{flavor}"
            name << "-#{features}"
            name << ".pko"
  
            FileUtils.mkpath(File.dirname("#{env[:TMP]}/#{name}")) rescue nil
  
            begin
              Packo.sh 'wget', '-c', '-O', "#{env[:TMP]}/#{name}", "#{_uri(package.repository)}/#{name}"
            rescue RuntimeError
              FileUtils.rm "#{env[:TMP]}/#{name}"
              fatal "Failed to download #{name}"
              exit 12
            end
  
            name = "#{env[:TMP]}/#{name}"
  
            if (digest = _digest(package, env)) && (result = Digest::SHA1.hexdigest(File.read(name))) != digest
              fatal "Digest mismatch (got #{result} expected #{digest}), install this package from source, the mirror could be compromised"
              exit 13
            end
  
            path = "#{env[:TMP]}/.__packo_unpacked/#{name[env[:TMP].length, name.length]}"
  
          when :source
            manifest = RBuild::Package::Manifest.parse(_manifest(package, env))

            unless options[:nodeps]
              manifest.blockers {|blocker|
                if blocker.build? && System.has?(blocker)
                  fatal "#{blocker} can't be installed with #{package}"
                  exit 16
                end
              }
      
              manifest.dependencies.each {|dependency|
                if dependency.build? && !System.has?(dependency)
                  install(dependency.to_s, dependency.type)
                end
              }
            end

            if options[:depsonly]
              exit 0
            end

            name = _build(package, env)

            if !name
              fatal "Something went wrong while trying to build #{package.to_s(:whole)}"
              exit 14
            end

            path = "#{env[:TMP]}/.__packo_unpacked/#{package.tags.to_s(true)}/#{name[env[:TMP].length + '.__packo_build/'.length, name.length]}"
        end
      else
        path = "#{System.env[:TMP]}/.__packo_unpacked/#{File.basename(name)}"
      end

      FileUtils.rm_rf path, :secure => true

      case File.extname(name)
        when '.pko'
          RBuild::Modules::Packaging::PKO.unpack(File.realpath(name), path)

          manifest = RBuild::Package::Manifest.open("#{path}/manifest.xml")

        else
          fatal 'Unknown package type'
          exit 15
      end

      package = Packo::Package.new(manifest.package.to_hash)

      if !options[:inherit]
        Environment[:FLAVOR] = Environment[:FEATURES] = ''
      end

      unless options[:nodeps]
        manifest.blockers {|blocker|
          if blocker.runtime? && System.has?(blocker)
            fatal "#{blocker} can't be installed with #{package}"
            exit 16
          end
        }

        manifest.dependencies.each {|dependency|
          if !System.has?(dependency) && dependency.runtime?
            install(dependency.to_s, dependency.type)
          end
        }
      end

      if options[:depsonly]
        exit 0
      end

      if System.has?(package)
        uninstall(package.to_s(:whole)) rescue nil
      end

      manifest.selectors.each {|selector|
        FileUtils.mkpath System.env[:SELECTORS]
        FileUtils.cp_r "#{path}/selectors/#{selector.path}", System.env[:SELECTORS], :preserve => true, :remove_destination => true
        Packo.sh 'packo-select', 'add', selector.name, selector.description, "#{System.env[:SELECTORS]}/#{selector.path}", :silent => true
      }

      pkg = Models::InstalledPackage.first_or_create(
        :tags_hashed => manifest.package.tags.hashed,
        :name        => manifest.package.name,
        :version     => manifest.package.version,
        :slot        => manifest.package.slot
      )

      pkg.update(
        :repo => options[:repository],

        :revision => manifest.package.revision,

        :flavor   => manifest.package.flavor,
        :features => manifest.package.features,
        
        :manual => manual,
        :type   => type
      )

      manifest.package.tags.each {|tag|
        pkg.tags.first_or_create(:name => tag.to_s)
      }

      length = "#{path}/dist".length
      old    = path

      contents = Hash[:dir => [], :obj => [], :sym => []]

      begin
        Find.find("#{path}/dist") {|file|
          type = nil
          path = "#{optionos[:destination]}/#{file[length, file.length]}".gsub(%r{/*/}, '/').sub(%r{/$}, '')
          fake = path[options[:destination].length, path.length] || ''
          meta = nil

          if !options[:force] && File.exists?(path) && !File.directory?(path)
            if (tmp = _exists?(fake))
              fatal "#{path} belongs to #{tmp}, use --force to overwrite"
            else
              fatal "#{path} doesn't belong to any package, use --force to overwrite"
            end

            raise RuntimeError.new 'File collision'
          end
  
          if File.symlink?(file)
            contents[type = :sym] << [path, meta = File.readlink(file)]
          elsif File.directory?(file)
            contents[type = :dir] << path
          elsif File.file?(file)
            contents[type = :obj] << [path, file]
            meta                   = Digest::SHA1.hexdigest(File.read(file))
          else
            next
          end

          case type
            when :dir; puts "--- #{path if path != '/'}/"
            when :sym; puts ">>> #{path} -> #{meta}".cyan.bold
            when :obj; puts ">>> #{path}".bold
          end

          content = pkg.contents.first_or_create(
            :type => type,
            :path => fake
          )

          content.attributes = {
            :meta => meta
          }
        }

        contents[:dir].each {|dir|
          FileUtils.mkpath(dir) rescue nil
        }

        contents[:obj].each {|(to, from)|
          FileUtils.cp(from, to, :preserve => true) rescue nil
        }

        contents[:sym].each {|(file, link)|
          FileUtils.ln_sf(link, file) rescue nil
        }

        pkg.save
      rescue Exception => e
        fatal 'Something went deeply wrong while installing package contents'
        Packo.debug e

        pkg.destroy rescue nil

        uninstall(package.to_s(:whole))

        exit 17
      end

      if outside && !options[:force]
        pkg.destroy
      end
    }
  end

  desc 'uninstall PACKAGE...', 'Uninstall packages'
  map '-C' => :uninstall, '-R' => :uninstall, 'remove' => :uninstall
  method_option :destination, :type => :string,  :aliases => '-d', :default => '/',   :desc => 'Set the destination where to install the package'
  method_option :force,       :type => :boolean, :aliases => '-f', :default => false, :desc => 'Force installation when something minor goes wrong'
  def uninstall (*names)
    names.each {|name|
      packages = _search_installed(name)
      
      if packages.empty?
        fatal "No installed packages match #{name}"
        exit 20
      end

      packages.each {|installed|
        installed.model.contents.each {|content|
          path = "#{options[:destination]}/#{content.path}".gsub(%r{/*/}, '/')

          case content.type
            when :obj
              if File.exists?(path) && (options[:force] || content.meta == Digest::SHA1.hexdigest(File.read(path)))
                puts "<<< #{path}".bold
                FileUtils.rm_f(path) rescue nil
              else
                 puts "=== #{path}".red
              end

            when :sym
              if File.exists?(path) && (options[:force] || !File.exists?(path) || content.meta == File.readlink(path))
                puts "<<< #{path} -> #{content.meta}".cyan.bold
                FileUtils.rm_f(path) rescue nil
              else
                puts "=== #{path} -> #{File.readlink(path)}".red
              end

            when :dir
              puts "--- #{path if path != '/'}/"
          end
        }

        installed.model.contents.all(:type => :dir, :order => [:path.desc]).each {|content|
          path = "#{options[:destination]}/#{content.path}".gsub(%r{/*/}, '/')

          Dir.delete(path) rescue nil
        }

        installed.model.destroy
      }
    }
  end

  desc 'search [EXPRESSION]', 'Search through installed packages'
  map '--search' => :search, '-Ss' => :search
  method_option :type,       :type => :string,  :aliases => '-t',                    :desc => 'The repository type (binary, source, virtual)'
  method_option :repository, :type => :string,  :aliases => '-r',                    :desc => 'Set a specific repository'
  method_option :full,       :type => :boolean, :aliases => '-F', :default => false, :desc => 'Include the repository that owns the package, features and flavor'
  def search (expression='')
    search_installed(expression, options[:repository], options[:type]).group_by {|package|
      "#{package.tags}/#{package.name}"
    }.sort.each {|(name, packages)|
      if options[:full]
        packages.group_by {|package|
          "#{package.repository.type}/#{package.repository.name}" rescue nil
        }.each {|name, packages|
          packages.group_by {|package|
            "#{package.features} #{package.flavor}"
          }.each {|name, packages|
            print "#{packages.first.tags}/#{packages.first.name.bold}"

            print ' ('
            print packages.map {|package|
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

        print packages.map {|package|
          "#{package.version.to_s.red}" + (package.slot ? "%#{package.slot.to_s.blue.bold}" : '')
        }.join(', ')

        print ")"
      end
      
      print "\n"
    }
  end

  desc 'info [EXPRESSION]', 'Search through installed packages and returns detailed informations about them'
  map '--info' => :info
  method_option :type,       :type => :string, :aliases => '-t', :desc => 'The repository type (binary, source, virtual)'
  method_option :repository, :type => :string, :aliases => '-r', :desc => 'Set a specific repository'
  def info (expression='')
    search_installed(expression, options[:repository], options[:type]).map {|package|
      search("#{package.to_s(:name)}-#{package.version}", (package.repository.name rescue nil), (package.repository.type rescue nil), true).first
    }.compact.each {|package|
      print "[#{"source/#{package.repository.name}".black.bold}] "
      print package.name.bold
      print "-#{package.version.to_s.red}"
      print " (#{package.slot.to_s.blue.bold})" if package.slot
      print " <#{package.tags.join(' ').magenta}>"
      print "\n"

      puts "    #{'Description'.green}: #{package.description}"
      puts "    #{'Homepage'.green}:    #{package.homepage}"
      puts "    #{'License'.green}:     #{package.license}"
      puts "    #{'Maintainer'.green}:  #{package.model.maintainer || 'nobody'}"

      case package.repository.type
        when :binary
          puts "    #{'Features'.green}:    #{package.features.to_a.select {|f| f.enabled?}.map {|f| f.name}.join(' ')}"

          print "    #{'Builds'.green}:      "
          package.model.data.builds.each {|build|
            print 'With '

            if !build.features.empty?
              print build.features.bold
            else
              print 'nothing'
            end

            print " in #{build.flavor.bold} flavor" if build.flavor
            print " (SHA1 #{build.digest})".black.bold if build.digest
            print "\n                 "
          }

        when :source
          (print "\n"; next) unless package.model.data.features.length > 0

          print "    #{'Features'.green}:    "

          features = package.model.data.features
          length   = features.map {|feature| feature.name.length}.max

          features.each {|feature|
            if feature.enabled?
              print "#{feature.name.white.bold}#{System.env[:NO_COLORS] ? '!' : ''}"
            else
              print feature.name.black.bold
            end

            print "#{' ' * (4 + length - feature.name.length + (System.env[:NO_COLORS] && !feature.enabled ? 1 : 0))}#{feature.description || '...'}"

            print "\n                 "
          }
      end

      print "\n"
    }
  end

  desc 'Manages various informations about package contents'
  def files
    require 'packo/cli/files'
    Packo::CLI::Files.start(ARGV[1, ARGV.length])
  end

  desc 'Manages packø building system'
  def build
    require 'packo/cli/build'
    Packo::CLI::Build.start(ARGV[1, ARGV.length])
  end

  desc 'Manages various configurations'
  def select
    require 'packo/cli/select'
    Packo::CLI::Select.start(ARGV[1, ARGV.length])
  end

  desc 'Manages packø repositories'
  def repository
    require 'packo/cli/repository'
    Packo::CLI::Repository.start(ARGV[1, ARGV.length])
  end

  desc 'Manages packø environment'
  def env
    require 'packo/cli/env'
    Packo::CLI::Environment.start(ARGV[1, ARGV.length])
  end

  private

  def _uri (repository)
    Repository.first(Package::Repository.parse(name).to_hash).URI rescue nil
  end

  def _build (package, env)

    FileUtils.rm_rf "#{env[:TMP]}/.__packo_build", :secure => true rescue nil
    FileUtils.mkpath "#{env[:TMP]}/.__packo_build" rescue nil

    require 'packo/cli/build'

    begin
      Packo::CLI::Build.start(['package' "--output='#{env[:TMP]}/.__packo_build'", "--repository='#{package.repository}", package.to_s(:whole)])
      return Dir.glob("#{env[:TMP]}/.__packo_build/#{package.name}-#{package.version}*.pko").first
    rescue SystemExit
      raise RuntimeError.new('Failed to build package')
    end
  end

  def _manifest (package, env)
    `sandbox packo-build --repository='#{package.repository}' manifest #{package.to_s(:whole)}`.strip
  end

  def _has (package, env)
    !!_search(package.to_s(:whole), package.repository.name, package.repository.type).find {|package|
      !!package.model.data.builds.to_a.find {|build|
        build.features.split(/\s+/).sort == env[:FEATURES].split(/\s+/).sort && \
        build.flavor.split(/\s+/).sort   == env[:FLAVOR].split(/\s+/).sort
      }
    }
  end

  def _filter (package, env)
    env[:FLAVOR] = env[:FLAVOR].split(/\s+/).reject {|f| f == 'binary'}.join(' ')

    features       = _search(package.to_s(:whole), package.repository.name, package.repository.type).first.features
    env[:FEATURES] = env[:FEATURES].split(/\s+/).delete_if {|f|
      !features.has?(f)
    }.join(' ')
  end

  def _digest (package, env)
    _search(package, package.repository.name, :binary).find {|package|
      package.model.data.builds.to_a.find {|build|
        build.features.split(/\s+/).sort == env[:FEATURES].split(/\s+/).sort && \
        build.flavor.split(/\s+/).sort   == env[:FLAVOR].split(/\s+/).sort
      }
    }.model.data.digest
  end

  def _exists? (path)
    Models::InstalledPackage::Content.first(:path => path, :type.not => :dir).package rescue false
  end
end

end; end
