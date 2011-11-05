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
require 'packo/do/repository'

module Packo; module CLI

class Repository < Thor
	include Thor::Actions

	class_option :help,
		type: :boolean, desc: 'Show help usage'

	desc 'add LOCATION...', 'Add repositories'
		map '-a' => :add

		method_option :ignore, aliases: '-i', type: :boolean, default: true,
			desc: 'Do not add the packages of a virtual repository to the index'

	def add (*locations)
		locations.map {|location|
			(Do::Repository::Remote.get(location).location rescue nil) || Location.parse(location)
		}.each {|location|
			begin
				repository = Do::Repository.add(location)

				CLI.info "Added #{repository}"
			rescue Do::Repository::Exceptions::AlreadyExists => e
				CLI.fatal e.message
			rescue Exception => e
				CLI.fatal "Failed to add #{location}"

				Packo.debug e
			end
		}
	end

	desc 'delete REPOSITORY...', 'Delete installed repositories'
		map '-d' => :delete, '-R' => :delete

	def delete (*names)
		names.each {|name|
			repository = Packo::Repository.parse(name)

			if repository.type && !Packo::Repository::Types.member?(repository.type)
				CLI.fatal "#{repository.type} is not a valid repository type"
				exit 20
			end

			conditions        = Hash[name: repository.name]
			conditions[:type] = repository.type if repository.type

			repositories = Models::Repository.all(conditions)

			if repositories.empty?
				CLI.fatal "#{repository.type}/#{repository.name} doesn't exist"
				exit 21
			end

			CLI.info "Deleting #{[repository.type, repository.name].join('/')}"

			begin
				repositories.each {|repository|
					Do::Repository.delete(repository)
				}
			rescue Exception => e
				CLI.fatal "Something went wrong while deleting #{name}"

				Packo.debug e
			end
		}
	end

	desc 'update [REPOSITORY...]', 'Update installed repositories'
		map '-u' => :update

		method_option :force, aliases: '-f', type: :boolean, default: false,
			desc: 'Force the update'

		method_option :ignore, aliases: '-i', type: :boolean, default: true,
			desc: 'Do not add the packages of a virtual repository to the index'

	def update (*repositories)
		Models::Repository.all.map {|repository|
			Packo::Repository.wrap(repository)
		}.each {|repository|
			next unless repositories.empty? || repositories.member?(repository.to_s)

			if Do::Repository.update(repository, options)
				CLI.info "Updated #{repository}"
			else
				CLI.info "#{repository} already up to date"
			end
		}
	end

	desc 'rehash [REPOSITORY...]', 'Rehash the repository caches'
	def rehash (*repositories)
		Models::Repository.all.map {|repository|
			Packo::Repository.wrap(repository)
		}.each {|repository|
			next unless repositories.empty? || repositories.member?(repository.to_s)

			CLI.info "Rehashing #{repository}"
			Do::Repository.rehash(repository)
			puts ''
		}
	end

	desc 'search [EXPRESSION] [OPTIONS]', 'Search packages with the given expression'
		map '--search' => :search, '-Ss' => :search

		method_option :exact, aliases: '-e', type: :boolean, default: false,
			desc: 'Search for the exact name'

		method_option :full, aliases: '-F', type: :boolean, default: false,
			desc: 'Include the repository that owns the package'

		method_option :type, aliases: '-t', type: :string,
			desc: 'The repository type'

		method_option :repository, aliases: '-r', type: :string,
			desc: 'Set a specific repository'

	def search (expression='')
		Models.search(expression, options).group_by {|package|
			"#{package.tags}/#{package.name}"
		}.sort.each {|(name, packages)|
			if options[:full]
				packages.group_by {|package|
					"#{package.repository.type}/#{package.repository.name}"
				}.each {|name, packages|
					print "#{"#{packages.first.tags}/" unless packages.first.tags.empty?}#{packages.first.name.bold}"

					print ' ('
					print packages.sort {|a, b|
						a.version <=> b.version
					}.map {|package|
						"#{package.version.to_s.red}" + (package.slot ? "%#{package.slot.to_s.blue.bold}" : '')
					}.join(', ')
					print ')'

					print " <#{"#{package.repository.type}/#{package.repository.name}".black.bold} | #{package.repository.location} | #{package.repository.path}>"
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

	desc 'info [EXPRESSION] [OPTIONS]', 'Search packages with the given expression and return detailed informations about them'
		map '--info' => :info, '-I' => :info

		method_option :exact, aliases: '-e', type: :boolean, default: false,
			desc: 'Search for the exact name'

		method_option :type, aliases: '-t', type: :string,
			desc: 'The repository type'

		method_option :repository, aliases: '-r', type: :string,
			desc: 'Set a specific repository'

	def info (expression='')
		Models.search(expression, options).group_by {|package|
			package.name
		}.sort.each {|(name, packages)|
			packages.sort {|a, b|
				a.version <=> b.version
			}.each {|package|
				print "<#{"source/#{package.repository.name}".black.bold}> "
				print package.name.bold
				print "-#{package.version.to_s.red}"
				print " {#{package.revision.yellow.bold}}" if package.revision > 0
				print " (#{package.slot.blue.bold})" if package.slot
				print " [#{package.tags.join(' ').magenta}]" if !package.tags.empty?
				print "\n"

				puts "    #{'Description'.green}: #{package.description}"      if package.description
				puts "    #{'Homepage'.green}:    #{package.homepage}"         if package.homepage
				puts "    #{'License'.green}:     #{package.license}"          if package.license
				puts "    #{'Maintainer'.green}:  #{package.model.maintainer}" if package.maintainer

				case package.repository.type
					when :binary
						puts "    #{'Features'.green}:    #{package.features.to_a.select {|f| f.enabled?}.map {|f| f.name}.join(' ')}"

						print "    #{'Builds'.green}:      "
						package.model.builds.each {|build|
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
						length = (package.model.flavor.to_a + package.model.features.to_a).map {|f|
							f.name.length
						}.max

						if package.model.flavor.length > 0
							print "    #{'Flavor'.green}:      "

							flavor = package.model.flavor

							flavor.each {|element|
								if element.enabled
									print "#{element.name.white.bold}#{System.env[:NO_COLORS] ? '!' : ''}"
								else
									print element.name.black.bold
								end

								print "#{' ' * (4 + length - element.name.length + (System.env[:NO_COLORS] && !element.enabled ? 1 : 0))}#{element.description || '...'}"

								print "\n                   "
							}

							print "\r" if package.model.features.length > 0
						end

						if package.model.features.length > 0
							print "    #{'Features'.green}:    "

							features = package.model.features

							features.each {|feature|
								if feature.enabled
									print "#{feature.name.white.bold}#{System.env[:NO_COLORS] ? '!' : ''}"
								else
									print feature.name.black.bold
								end

								print "#{' ' * (4 + length - feature.name.length + (System.env[:NO_COLORS] && !feature.enabled ? 1 : 0))}#{feature.description || '...'}"

								print "\n                 "
							}
						end
				end

				print "\n"
			}
		}
	end

	desc 'list [TYPE]', 'List installed repositories'
	def list (type='all')
		if Packo::Repository::Types.member?(type.to_sym)
			CLI.info "Installed #{type} repositories:"

			repositories = Models::Repository.from_sym(type).all
			length       = repositories.map {|repository| "#{repository.type}/#{repository.name}".length}.max

			repositories.each {|repository|
				puts "  #{repository.type.to_sym}/#{repository.name}#{' ' * (4 + length - "#{repository.type}/#{repository.name}".length)}#{repository.location} (#{repository.path})"
			}

			puts ''
		elsif type == 'all'
			Packo::Repository::Types.each {|type|
				list(type)
			}
		end
	end

	desc 'path REPOSITORY', 'Output the path of a given repository'
	def path (name)
		repository = Packo::Repository.parse(name)
		repository = Models::Repository.from_sym(repository.type).first(name: repository.name)

		exit if !repository

		puts repository.path
	end

	desc 'location REPOSITORY', 'Output the URI of a given package'
	def location (name)
		repository = Packo::Repository.parse(name)
		repository = Models::Repository.from_sym(repository.type).first(name: repository.name)

		exit if !repository

		location = repository.location
		length   = location.to_hash.map {|name, value|
			name.length
		}.max

		puts "#{'Type'.green}:#{' ' * (length - 4)} #{location.type}"

		location.to_hash.each {|name, value|
			puts "#{name.to_s.capitalize.green}:#{' ' * (length - name.length)} #{value}"
		}
	end

	desc 'generate REPOSITORY.. [OPTIONS]', 'Generate a binary repository from sources'
		method_option :repository, aliases: '-r', type: :string,
			desc: 'Specify a source repository from where to get packages'

		method_option :output, aliases: '-o', type: :string, default: "#{System.env[:TMP]}/generated",
			desc: 'Specify output directory'

		method_option :wipe, aliases: '-w', type: :boolean, default: false,
			desc: 'Overwrite already generated packages'

	def generate (*repositories)
		repositories.each {|repository|
			data = Do::Repository.generate(repository, options)

			path = repository.sub(/(\..*?)$/, '.generated\1')

			if File.writable?(path)
				File.write(path, data)
			else
				path = "#{System.env[:TMP]}/#{File.basename(path)}"

				File.write(path, data)

				CLI.info "You can find the generate repository here: #{path}"
			end
		}
	rescue Errno::EACCES
		CLI.fatal 'Try to use packo-repository instead.'
	end

	def initialize (*args)
		FileUtils.mkpath(System.env[:TMP])
		File.umask 022

		super(*args)
	end
end

end; end
