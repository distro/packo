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

module Packo; module RBuild; module Modules; module Packaging

Packager.register('pko') {
	pack do |package, to|
		Dir.chdir package.directory

		package.filesystem.pre.save("#{package.directory}/pre", 0755)
		package.filesystem.post.save("#{package.directory}/post", 0755)
		package.filesystem.selectors.save("#{package.directory}/selectors", 0755)

		manifest.new(package).save('manifest.yml')

		package.callbacks(:packing).do {
			Do.clean(package.distdir)

			Packo.sh 'tar', 'cJf', to, *['dist/', 'pre/', 'post/', 'selectors/', 'manifest.yml'], '--preserve-permissions', silent: true
		}

		to
	end

	unpack do |package, to=nil|
		FileUtils.mkpath(to) rescue nil

		Packo.sh 'tar', 'xJf', pacakage, '-C', to || "#{System.env[:TMP]}/.__packo_unpacked/#{File.basename(package)}", '--preserve', :silent => true
	end

	manifest do
		require 'base64'

		def self.parse (text)
			data = YAML.parse(text).transform

			new(Package.new(
				maintainer: data['maintainer'],

				tags:     Packo::Package::Tags.parse(data['tags']),
				name:     data['name'],
				version:  Versionub.parse(data['version']),
				slot:     data['slot'],
				revision: data['revision'],

				size: data['size'],

				exports: Marshal.load(Base64.decode64(data['exports'])),

				description: data['description'],
				homepage:    data['homepage'].split(/\s+/),
				license:     data['license'].split(/\s+/),

				flavor:   Packo::Package::Flavor.parse(data['flavor'] || ''),
				features: Packo::Package::Features.parse(data['features'] || ''),

				environment: data['environment'],

				dependencies: data['dependencies'],

				selectors: data['selectors']
			))
		end

		def to_yaml (options={})
			data = {}

			data.merge!(Hash[package.to_hash.map {|name, value|
				next if value.nil?

				[name.to_s, value.to_s]
			}.compact])

			data['environment'] = package.env!.reject {|name, value|
				%w(DATABASE FLAVORS PROFILES CONFIG_PATH MAIN_PATH INSTALL_PATH FETCHER NO_COLORS DEBUG VERBOSE TMP SECURE).member(name.to_s)
			}.map {|name, value|
				next if value.nil?

				[name.to_s, value.to_s]
			}.compact

			data['size']    = package.size
			data['exports'] = Base64.encode64(Marshal.dump(package.exports))

			data['dependencies'] = package.dependencies.map {|dependency|
				dependency.to_s
			}

			data['selectors'] = package.selectors.map {|selector|
				selector.to_hash
			}

			data.to_yaml
		end

		alias to_s to_yaml
	end
}

end; end; end; end
