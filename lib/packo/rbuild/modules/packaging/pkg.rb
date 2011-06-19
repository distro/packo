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

Packager.register('.pko') {
  pack do |package, to=nil|
    path = to || "#{package.to_s(:package)}.pkg"

    Dir.chdir package.directory

    # TODO: convert pre/post scripts to arch's *.install

    manifest.new(package).save('dist/.PKGINFO')

    package.callbacks(:packing).do {
      Do.clean(package.distdir)

      Do.cd 'dist' do
        Packo.sh 'tar', 'cJf', path, '.', '--preserve', silent: true
      end
    }

    path
  end

  unpack do |package, to=nil|
    FileUtils.mkpath(to) rescue nil

    Packo.sh 'tar', 'xJf', pacakage, '-C', to || "#{System.env[:TMP]}/.__packo_unpacked/#{File.basename(package)}", '--preserve', :silent => true
  end

  manifest do
    def self.parse (text)
      data = {}

      text.lines.each {|line|
      }

      self.new(OpenStruct.new(data)
=begin
        maintainer: data['package']['maintainer'],

        tags:    Packo::Package::Tags.parse(data['package']['tags']),
        name:    data['package']['name'],
        version: Versionub.parse(data['package']['version']),
        slot:    data['package']['slot'],

        exports: Marshal.load(Base64.decode64(data['package']['exports'])),

        description: data['package']['description'],
        homepage:    data['package']['homepage'].split(/\s+/),
        license:     data['package']['license'].split(/\s+/),

        flavor:   Packo::Package::Flavor.parse(data['package']['flavor'] || ''),
        features: Packo::Package::Features.parse(data['package']['features'] || ''),

        environment: data['package']['environment'],

        dependencies: Package::Dependencies.new(data['dependencies'].map {|dependency|
          Package::Dependency.parse(dependency)
        }),

        selector: data['selectors']
      ))
=end
    end

    def self.open (path)
      self.parse(File.read(path))
    end

    attr_reader :package, :dependencies, :selectors

    def initialize (what)
      @package = OpenStruct.new(
        maintainer: what.maintainer,

        tags:     what.tags,
        name:     what.name,
        version:  what.version,
        slot:     what.slot,
        revision: what.revision,

        exports: what.exports,

        description: what.description,
        homepage:    [what.homepage].flatten.compact.join(' '),
        license:     [what.license].flatten.compact.join(' '),

        flavor:   what.flavor,
        features: what.features,

        size: what.size,

        environment: what.environment.reject {|name, value|
          [:DATABASE, :FLAVORS, :PROFILES, :CONFIG_PATH, :MAIN_PATH, :INSTALL_PATH, :FETCHER,
           :NO_COLORS, :DEBUG, :VERBOSE, :TMP, :SECURE
          ].member?(name.to_sym)
        }
      )

      @dependencies = what.dependencies
      @selectors    = [what.selector].flatten.compact.map {|selector| OpenStruct.new(selector)}

      if (what.filesystem.selectors rescue false)
        what.filesystem.selectors.each {|name, file|
          matches = file.content.match(/^#\s*(.*?):\s*(.*)([\n\s]*)?\z/) or next

          @selectors << OpenStruct.new(name: matches[1], description: matches[2], path: name)
        }
      end
    end

    def save (to, options={})
      File.write(to, self.to_s)
    end

    def to_s (options={})
      data = {}

      data[:pkgname] = package.name
      data[:pkgver]  = "#{package.version}-#{package.revision || 1}"

      data[:pkgdesc]   = package.description
      data[:url]       = package.homepage
      data[:builddate] = 0
      data[:size]      = package.size || 0

      data.map {|name, value|
        [value].flatten.compact.map {|value|
          "#{name} = #{value}"
        }.join("\n")
      }.join("\n")
    end
  end
}

end; end; end; end
