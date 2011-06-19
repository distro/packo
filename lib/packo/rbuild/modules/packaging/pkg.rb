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

Packager.register('pkg') {
  pack do |package, to=nil|
    path = to || "#{package.to_s(:package)}.pkg"

    Dir.chdir package.directory

    # TODO: convert pre/post scripts to arch's .install

    manifest.new(package).save('dist/.PKGINFO')

    package.callbacks(:packing).do {
      Do.clean(package.distdir)

      Packo.sh 'tar', 'cJf', path, 'dist/', '--preserve-permissions', '-C', 'dist/', silent: true
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

      self.new(Package.new(data))
    end

    def to_s (options={})
      data = {}

      data[:pkgname]   = package.name
      data[:pkgver]    = "#{package.version}-#{package.revision || 1}"
      data[:pkgdesc]   = package.description
      data[:license]   = package.license
      data[:url]       = package.homepage
      data[:builddate] = package.built?.end.to_i || Time.now.to_i
      data[:size]      = package.size || 0
      data[:arch]      = package.target.arch
      data[:packager]  = package.maintainer

      data.map {|name, value|
        [value].flatten.compact.map {|value|
          "#{name} = #{value}"
        }.join("\n")
      }.join("\n") + "\n"
    end
  end
}

end; end; end; end
