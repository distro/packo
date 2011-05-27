#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free :software => you can redistribute it and/or modify
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

pack = lambda do |name, *files|
  Packo.sh 'tar', 'cJf', name, *files, '--preserve', :silent => true
end

unpack = lambda do |name, to|
  FileUtils.mkpath(to) rescue nil

  Packo.sh 'tar', 'xJf', name, '-C', to, '--preserve', :silent => true
end

Packager.register(:pack, '.pko') do |package, to=nil|
  path = to || "#{package.to_s(:package)}.pko"

  Dir.chdir package.directory

  package.filesystem.pre.save("#{package.directory}/pre", 0755)
  package.filesystem.post.save("#{package.directory}/post", 0755)
  package.filesystem.selectors.save("#{package.directory}/selectors", 0755)

  Package::Manifest.new(package).save('manifest.xml')

  package.callbacks(:packing).do {
    Do.clean(package.distdir)

    pack.call(path, 'dist/', 'pre/', 'post/', 'selectors/', 'manifest.xml')
  }

  path
end

Packager.register(:unpack, '.pko') do |package, to=nil|
  unpack.call(package, to || "#{System.env[:TMP]}/.__packo_unpacked/#{File.basename(package)}")
end

end; end; end; end
