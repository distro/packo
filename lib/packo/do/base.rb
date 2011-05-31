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

require 'packo/do/build'

module Packo; class Do

class Base
  def self.install (name)
    type = names.last.is_a?(Symbol) ? names.pop : :both

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

            if (digest = Do::Repository.digest(package, env)) && (result = Packo.digest(name)) != digest
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

            exit 0 if options[:depsonly]

            name = Do::Build.build(package, env)

            if !name
              CLI.fatal "Something went wrong while trying to build #{package.to_s(:whole)}"
              exit 14
            end

            path = "#{env[:TMP]}/.__packo_unpacked/#{package.tags.to_s(true)}/#{name[env[:TMP].length + '.__packo_build/'.length, name.length]}"
        end
      else
        path = "#{System.env[:TMP]}/.__packo_unpacked/#{File.basename(name)}"
      end

      FileUtils.rm_rf path, secure: true

      case File.extname(name)
        when '.pko'
          RBuild::Modules::Packager.unpack(File.realpath(name), path)

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
        FileUtils.cp_r "#{path}/selectors/#{selector.path}", System.env[:SELECTORS], preserve: true, remove_destination: true
        Packo.sh 'packo-select', 'add', selector.name, selector.description, "#{System.env[:SELECTORS]}/#{selector.path}", silent: true
      }

      Models.transaction {|t|
        pkg = Models::InstalledPackage.first_or_new(
          tags_hashed: manifest.package.tags.hashed,
          name:        manifest.package.name,
          slot:        manifest.package.slot
        )

        pkg.attributes = {
          repo: options[:repository],

          version:  manifest.package.version,
          revision: manifest.package.revision,

          flavor:   manifest.package.flavor,
          features: manifest.package.features,

          description: manifest.package.description,
          homepage:    manifest.package.homepage,
          license:     manifest.package.license,

          manual: manual,
          type:   type
        }

        pkg.save

        manifest.package.tags.each {|tag|
          pkg.tags.first_or_create(name: tag.to_s)
        }

        length = "#{path}/dist/".length
        old    = path

        begin
          Packo.contents(Find.find("#{path}/dist")) {|file|
            if !file[length, file.length]
              { next: true }
            else
              { path: Path.clean(options[:destination] + file[length, file.length]) }
            end
          }.each {|file|
            if !options[:force] && File.exists?(file.path) && !File.directory?(file.path)
              if (tmp = Models.exists?(file.path))
                CLI.fatal "#{file.path} belongs to #{tmp}, use --force to overwrite"
              else
                CLI.fatal "#{file.path} doesn't belong to any package, use --force to overwrite"
              end

              raise RuntimeError.new 'File collision'
            end

            case file.type
              when :dir
                begin
                  FileUtils.mkpath(file.path)
                  puts "--- #{file.path if file.path != '/'}/"
                rescue
                  puts "--- #{file.path if file.path != '/'}/".red
                end

              when :sym
                begin
                  FileUtils.ln_sf file.meta, file.path
                  puts ">>> #{file.path} -> #{file.meta}".cyan.bold
                rescue
                  puts ">>> #{file.path} -> #{file.meta}".red
                end

              when :obj
                begin
                  FileUtils.cp file.source, file.path, preserve: true
                  puts ">>> #{file.path}".bold
                rescue
                  puts ">>> #{file.path}".red
                end
            end

            content = pkg.contents.first_or_create(
              type: file.type,
              path: file.path
            )

            content.update(
              meta: file.meta
            )
          }

          pkg.save
        rescue Exception => e
          CLI.fatal 'Something went deeply wrong while installing package contents'
          Packo.debug e

          pkg.contents.each {|content| content.check!
            path = "#{installed.model.destination}/#{content.path}".gsub(%r{/*/}, '/')

            case content.type
              when :obj
                if File.exists?(path) && (options[:force] || content.meta == Packo.digest(path))
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

          pkg.contents.all(type: :dir, order: [:path.desc]).each {|content|
            path = "#{options[:destination]}/#{content.path}".gsub(%r{/*/}, '/')

            Dir.delete(path) rescue nil
          }

          t.rollback

          exit 17
        end

        if options[:ignore]
          t.rollback
        else
          pkg.update(destination: Path.clean(options[:destination]))
        end
      }
    }

  end

  def self.uninstall (name)
    names.each {|name|
      packages = Models.search_installed(name)

      if packages.empty?
        CLI.fatal "No installed packages match #{name}"

        exit 20
      end

      packages.each {|installed|
        if installed.repository && installed.repository.type == :virtual
          repository.uninstall(installed) or next
        end

        Models.transaction {
          installed.model.contents.each {|content| content.check!
            path = "#{installed.model.destination}/#{content.path}".gsub(%r{/*/}, '/')

            case content.type
              when :obj
                if File.exists?(path) && (options[:force] || content.meta == Packo.digest(path))
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

          installed.model.contents.all(type: :dir, order: [:path.desc]).each {|content|
            path = "#{options[:destination]}/#{content.path}".gsub(%r{/*/}, '/')

            Dir.delete(path) rescue nil
          }

          installed.model.destroy
        }
      }
    }
  end

  def self.update (name)

  end
end

end; end
