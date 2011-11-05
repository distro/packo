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

require 'packo/rbuild/stages'
require 'packo/rbuild/features'
require 'packo/rbuild/flavor'

require 'packo/rbuild/modules'
require 'packo/rbuild/behaviors'

module Packo; module RBuild

class Package < Packo::Package
	def self.const_missing (name)
		RBuild.const_get(name) rescue
		RBuild::Modules.const_get(name) rescue
		RBuild::Behaviors.const_get(name) rescue
		super
	end

	def self.load (path)
		directory = File.dirname(path)
		name      = File.basename(path).sub(/.rbuild$/, '')

		if ((package = Package.parse(name)).version rescue false)
			files = {}

			if File.exists?("#{directory}/digest.yml") && (digest = YAML.parse_file("#{directory}/digest.yml").transform)
				pkg = digest.find {|pkg|
					pkg['version'] == package.version && (!package.slot || pkg['slot'] == package.slot)
				}

				if pkg && pkg['files']
					pkg['files'].each {|file|
						tmp = OpenStruct.new(file)

						files[file['name']] = tmp
						files[file['url']]  = tmp
					}
				end
			end

			ver = package.version

			Package.new {
				self.path = path

				if File.exists? "#{directory}/#{package.name}.rbuild"
					if (tmp = File.read("#{directory}/#{package.name}.rbuild", encoding: 'utf-8').split(/^__END__$/)).length > 1
						filesystem.parse(tmp.last.lstrip)
					end

					parent "#{directory}/#{package.name}.rbuild"
				end

				if (tmp = File.read(path, encoding: 'utf-8').split(/^__END__$/)).length > 1
					filesystem.parse(tmp.last.lstrip)
				end

				if File.directory? "#{directory}/data"
					filesystem.load "#{directory}/data"
				end

				self.digests = files

				version ver
				main path
			}
		else
			Package.new {
				self.path = path

				if (tmp = File.read(path, encoding: 'utf-8').split(/^__END__$/)).length > 1
					filesystem.parse(tmp.last.lstrip)
				end

				main path
			}
		end
	end

	include Callbackable

	attr_reader :do, :modules, :dependencies, :stages, :filesystem

	def initialize (name = nil, version = nil, slot = nil, revision = nil, &block)
		super(
			name:     name,
			version:  version,
			slot:     slot,
			revision: revision
		)

		@filesystem = FFFS::FileSystem.new

		%w(pre post selectors patches files).each {|dir|
			@filesystem << FFFS::Directory.new(dir)
		}

		%w(pre post).each {|dir|
			%w(install uninstall).each {|target|
				@filesystem[dir] << FFFS::Directory.new(target)
			}
		}

		@modules      = []
		@stages       = Stages.new(self)
		@do           = Do.new(self)
		@dependencies = Dependencies.new(self)
		@features     = Features.new(self)
		@flavor       = Flavor.new(self)

		@stages.add :dependencies, at: :beginning do
			callbacks(:dependencies).do(self)
		end

		use      Modules::Fetcher, Modules::Unpacker, Modules::Packager
		behavior Behaviors::Default

		flavor {
			vanilla {
				description 'Apply only the patches needed to build succesfully the package'

				after :initialized do
					next unless enabled?

					flavor.each {|element|
						next if element.name == :vanilla

						element.disable!
					}
				end
			}

			documentation {
				description 'Add documentation to the package'

				before :pack, name: :documentation do
					next if flavor.vanilla?

					if !enabled?
						Find.find(distdir) {|file|
							if ['man', 'info', 'doc'].member?(File.basename(file)) && File.directory?(file)
								FileUtils.rm_rf(file, secure: true) rescue nil
							end
						}
					end
				end
			}

			headers {
				description 'Add headers to the package'

				before :pack, name: :headers do
					next if flavor.vanilla?

					if !enabled?
						Find.find(distdir) {|file|
							if ['include', 'headers'].member?(File.basename(file)) && File.directory?(file)
								FileUtils.rm_rf(file, secure: true) rescue nil
							end
						}
					end
				end
			}

			debug {
				description 'Make a debug build'
			}
		}

		instance_eval &block if block
	end

	def parent (path)
		instance_eval File.read(@parent = path), path, 0
	end

	def main (path)
		callbacks(:initialize).do(self) {

			instance_eval File.read(@main = path), path, 0

			self.directory = Path.clean("#{env[:TMP]}/#{tags.to_s(true)}/#{name}/#{slot}/#{version}")
			self.workdir   = "#{directory}/work"
			self.distdir   = self.installdir = "#{directory}/dist"
			self.tempdir   = "#{directory}/temp"
			self.fetchdir  = System.env[:FETCH_PATH] || tempdir
		}

		envify!
		export! :arch, :kernel, :compiler, :libc

		[flavor, features].each {|thing|
			tmp = []
			thing.each {|piece|
				next unless piece.enabled?

				tmp << piece.name
			}

			if thing.needs && !(expression = Boolean::Expression.parse(thing.needs)).evaluate(tmp)
				raise Boolean::Expression::EvaluationError.new "#{to_s :name}: could not ensure `#{expression}` for the #{thing.class.name.match(/(?:::)?([^:]*)$/)[1].downcase}"
			end

			thing.each {|piece|
				next unless piece.enabled? && piece.needs

				if !(expression = Packo::Boolean::Expression.parse(piece.needs)).evaluate(tmp)
					raise Boolean::Expression::EvaluationError.new "#{to_s :name}: could not ensure `#{expression}` for `#{piece.name}`"
				end
			}
		}

		callbacks(:initialized).do(self)
	end

	def create!
		FileUtils.mkpath workdir
		FileUtils.mkpath distdir
		FileUtils.mkpath tempdir
		FileUtils.mkpath fetchdir
	rescue; end

	def clean! (full = true)
		FileUtils.rm_rf distdir, secure: true

		if full
			FileUtils.rm_rf workdir, secure: true
			FileUtils.rm_rf tempdir, secure: true
		end
	rescue; end

	def build
		create!

		@build_start_at = Time.now

		Do.cd {
			callbacks(:build).do(self) {
				stages.each {|stage|
					yield stage if block_given?

					stage.call
				}
			}
		}

		@build_end_at = Time.now
	end

	def built?
		Struct.new(:start, :end).new(@build_start_at, @build_end_at) if @build_start_at
	end

	def use (*modules)
		modules.flatten.compact.each {|klass|
			if klass.is_a?(Module::Delete)
				@modules.delete(@modules.find {|mod|
					mod.class == klass.module
				}).finalize rescue nil
			else
				@modules << klass.new(self)
			end
		}
	end

	def using? (what)
		@modules.any? {|mod|
			mod.class == what
		}
	end

	def behavior (behavior)
		if @behavior
			@behavior.each {|mod|
				use -mod
			}
		end

		(@behavior = behavior).each {|mod|
			use mod
		}
	end

	def features (&block)
		block ? @features.dsl(&block) : @features
	end

	def flavor (&block)
		block ? @flavor.dsl(&block) : @flavor
	end

	def selectors
		filesystem.selectors.map {|name, file|
			matches = file.content.match(/^#\s*(.*?):\s*(.*)([\n\s]*)?\z/) or next

			Struct.new(:name, :description, :path).new(matches[1], matches[2], name)
		}.compact
	end

	def size
		result = 0

		Find.find(distdir) {|path|
			next unless File.file?(path)

			result += File.size(path) rescue nil
		}

		result
	end

	def package; self end

	def to_s (type = nil)
		return super(type) if super(type)

		case type
			when :package;    "#{name}-#{version}#{"%#{slot}" if slot}#{"+#{@flavor.to_s(:package)}" if !@flavor.to_s(:package).empty?}#{"-#{@features.to_s(:package)}" if !@features.to_s(:package).empty?}"
			when :everything; "#{super(:whole)} #{package.env!.reject {|n| n == :DEBUG}.to_s }}"
			else              "#{super(:whole)}#{"[#{@features.to_s}]" if !@features.to_s.empty?}#{"{#{@flavor.to_s}}" if !@flavor.to_s.empty?}"
		end
	end
end

end; end
