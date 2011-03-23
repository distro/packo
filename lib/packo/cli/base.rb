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

require 'packo'
require 'packo/models'
require 'packo/rbuild'

module Packo; module CLI

class Base < Thor
  include Thor::Actions

  class_option :help, :type => :boolean, :desc => 'Show help usage'

  desc 'install PACKAGE... [OPTIONS]', 'Install packages'
  map '-i' => :install, '--install' => :install
  method_option :destination, :type => :string,  :default => System.env[:INSTALL_PATH], :aliases => '-d', :desc => 'Set the destination where to install the package'
  method_option :inherit,     :type => :boolean, :default => false,                     :aliases => '-I', :desc => 'Apply the passed flags to the eventual dependencies'
  method_option :force,       :type => :boolean, :default => false,                     :aliases => '-f', :desc => 'Force installation when something minor goes wrong'
  method_option :ignore,      :type => :boolean, :default => false,                     :aliases => '-x', :desc => 'Ignore the installation and do not add the package to the database'
  method_option :nodeps,      :type => :boolean, :default => false,                     :aliases => '-N', :desc => 'Ignore blockers and dependencies'
  method_option :depsonly,    :type => :boolean, :default => false,                     :aliases => '-D', :desc => 'Install only dependencies'
  method_option :repository,  :type => :string,                                         :aliases => '-r', :desc => 'Set a specific repository'
  def install (*names)
    type = names.last.is_a?(Symbol) ? names.pop : :both

    FileUtils.mkpath options[:destination] rescue nil
    FileUtils.mkpath System.env[:SELECTORS] rescue nil

    binary = false

    if names.last === true
      manual = names.shift ? 0 : 1
    else
      manual = 1
    end

    names.each {|name|
      CLI.info "Installing #{name}"

      if File.extname(name).empty?
        packages = nil

        if System.env[:FLAVOR].include?('binary')
          packages = Models.search(name, options[:repository], :binary)

          if packages.empty?
            CLI.warn "#{name} could not be found in the binary repositories, looking in source repositories"
            packages = nil
          else
            binary = true
          end
        end

        begin
          if !packages
            packages = Models.search(name, options[:repository], :source)

            binary = false
          end

          names = packages.group_by {|package|
            "#{package.tags}/#{package.name}"
          }.map {|(name, package)| name}.uniq

          if names.length > 1
            CLI.fatal "More than one package matches: #{name}"
            names.each {|name|
              puts "    #{name}"
            }

            exit 10
          end

          package = packages.sort {|a, b|
            a.version <=> b.version
          }.last

          if !package
            CLI.fatal "#{name} not found"
            exit 11
          end

          env = Environment.new(package)

          if package.repository.type == :binary && !_has(package, env)
            CLI.warn 'The binary package is not available with the features you asked for, trying to build from source'
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
              CLI.fatal "Failed to download #{name}"
              exit 12
            end

            name = "#{env[:TMP]}/#{name}"

            if (digest = _digest(package, env)) && (result = Digest::SHA1.hexdigest(File.read(name))) != digest
              CLI.fatal "Digest mismatch (got #{result} expected #{digest}), install this package from source, the mirror could be compromised"
              exit 13
            end

            path = "#{env[:TMP]}/.__packo_unpacked/#{name[env[:TMP].length, name.length]}"

          when :source
            manifest = RBuild::Package::Manifest.parse(_manifest(package, env))

            unless options[:nodeps] || System.env[:NODEPS]
              manifest.blockers {|blocker|
                if blocker.build? && System.has?(blocker)
                  CLI.fatal "#{blocker} can't be installed with #{package}"
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
              CLI.fatal "Something went wrong while trying to build #{package.to_s(:whole)}"
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
          CLI.fatal 'Unknown package type'
          exit 15
      end

      package = Packo::Package.new(manifest.package.to_hash)

      if !options[:inherit]
        Environment[:FLAVOR] = Environment[:FEATURES] = ''
      end

      unless options[:nodeps] || System.env[:NODEPS]
        manifest.blockers {|blocker|
          if blocker.runtime? && System.has?(blocker)
            CLI.fatal "#{blocker} can't be installed with #{package}"
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

      pkg = Models::InstalledPackage.first_or_new(
        :tags_hashed => manifest.package.tags.hashed,
        :name        => manifest.package.name,
        :slot        => manifest.package.slot
      )

      pkg.attributes = {
        :repo => options[:repository],

        :version  => manifest.package.version,
        :revision => manifest.package.revision,

        :flavor   => manifest.package.flavor,
        :features => manifest.package.features,

        :description => manifest.package.description,
        :homepage    => manifest.package.homepage,
        :license     => manifest.package.license,

        :manual => manual,
        :type   => type
      }

      pkg.save

      manifest.package.tags.each {|tag|
        pkg.tags.first_or_create(:name => tag.to_s)
      }

      length = "#{path}/dist/".length
      old    = path

      begin
        Find.find("#{path}/dist") {|file|
          next unless file[length, file.length]

          type = nil
          path = (options[:destination] + file[length, file.length]).cleanpath.to_s
          fake = path[options[:destination].cleanpath.to_s.length, path.length] || ''
          meta = nil

          if !options[:force] && File.exists?(path) && !File.directory?(path)
            if (tmp = _exists?(fake))
              CLI.fatal "#{path} belongs to #{tmp}, use --force to overwrite"
            else
              CLI.fatal "#{path} doesn't belong to any package, use --force to overwrite"
            end

            raise RuntimeError.new 'File collision'
          end

          if File.directory?(file)
            type = :dir

            begin
              FileUtils.mkpath(path)
              puts "--- #{path if path != '/'}/"
            rescue
              puts "--- #{path if path != '/'}/".red
            end
          elsif File.symlink?(file)
            type = :sym
            meta = File.readlink(file)

            begin
              FileUtils.ln_sf meta, path
              puts ">>> #{path} -> #{meta}".cyan.bold
            rescue
              puts ">>> #{path} -> #{meta}".red
            end
          elsif File.file?(file)
            type = :obj
            meta = Digest::SHA1.hexdigest(File.read(file))

            begin
              FileUtils.cp file, path, :preserve => true
              puts ">>> #{path}".bold
            rescue
              puts ">>> #{path}".red
            end
          else
            next
          end

          content = pkg.contents.first_or_create(
            :type => type,
            :path => fake
          )

          content.update(
            :meta => meta
          )
        }

        pkg.save
      rescue Exception => e
        CLI.fatal 'Something went deeply wrong while installing package contents'
        Packo.debug e

        pkg.destroy rescue nil

        uninstall(package.to_s(:whole))

        exit 17
      end

      if options[:ignore]
        pkg.destroy
      else
        pkg.update(:destination => options[:destination].cleanpath)
      end
    }
  end

  desc 'uninstall PACKAGE... [OPTIONS]', 'Uninstall packages'
  map '-C' => :uninstall, '-R' => :uninstall, 'remove' => :uninstall
  method_option :force, :type => :boolean, :default => false, :aliases => '-f', :desc => 'Force installation when something minor goes wrong'
  def uninstall (*names)
    names.each {|name|
      packages = Models.search_installed(name)

      if packages.empty?
        CLI.fatal "No installed packages match #{name}"
        exit 20
      end

      packages.each {|installed|
        installed.model.contents.each {|content| content.check!
          path = "#{installed.model.destination}/#{content.path}".gsub(%r{/*/}, '/')

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

  desc 'search [EXPRESSION] [OPTIONS]', 'Search through installed packages'
  map '--search' => :search, '-Ss' => :search
  method_option :type,       :type => :string,                     :aliases => '-t', :desc => 'The repository type (binary, source, virtual)'
  method_option :repository, :type => :string,                     :aliases => '-r', :desc => 'Set a specific repository'
  method_option :full,       :type => :boolean, :default => false, :aliases => '-F', :desc => 'Include the repository that owns the package, features and flavor'
  def search (expression='')
    Models.search_installed(expression, options[:repository], options[:type]).group_by {|package|
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

  desc 'info [EXPRESSION] [OPTIONS]', 'Search through installed packages and returns detailed informations about them'
  map '--info' => :info
  method_option :type,       :type => :string, :aliases => '-t', :desc => 'The repository type (binary, source, virtual)'
  method_option :repository, :type => :string, :aliases => '-r', :desc => 'Set a specific repository'
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

  private

  def _uri (repository)
    Repository.first(Packo::Repository.parse(name).to_hash).URI rescue nil
  end

  def _build (package, env)
    Do.cd {
      FileUtils.rm_rf "#{System.env[:TMP]}/.__packo_build", :secure => true rescue nil
      FileUtils.mkpath "#{System.env[:TMP]}/.__packo_build" rescue nil

      require 'packo/cli/build'

      begin
        System.env.sandbox(env) {
          Packo::CLI::Build.start(['package', package.to_s(:whole), "--output=#{System.env[:TMP]}/.__packo_build", "--repository=#{package.repository}"])
        }
      rescue
      end

      Dir.glob("#{System.env[:TMP]}/.__packo_build/#{package.name}-#{package.version}*.pko").first
    }
  end

  def _manifest (package, env)
    tmp = Models.search(package.to_s, options[:repository])

    RBuild::Package::Manifest.new(
      Packo.loadPackage("#{tmp.last.repository.path}/#{tmp.last.model.data.path}", tmp.last)
    ).to_s
  end

  def _has (package, env)
    !!Models.search(package.to_s(:whole), package.repository.name, package.repository.type).find {|package|
      !!package.model.data.builds.to_a.find {|build|
        build.features.split(/\s+/).sort == env[:FEATURES].split(/\s+/).sort && \
        build.flavor.split(/\s+/).sort   == env[:FLAVOR].split(/\s+/).sort
      }
    }
  end

  def _digest (package, env)
    Models.search(package, package.repository.name, :binary).find {|package|
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
