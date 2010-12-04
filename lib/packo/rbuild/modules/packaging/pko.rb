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

module Packo; module RBuild; module Modules; module Packaging

class PKO < Module
  def self.pack (name, *files)
    Packo.sh 'tar', 'cJf', name, *files, '--preserve', :silent => true
  end

  def self.unpack (name, to)
    FileUtils.mkpath(to) rescue nil

    Packo.sh 'tar', 'xJf', name, '-C', to, '--preserve', :silent => true
  end

  def initialize (package)
    super(package)

    package.stages.add :pack, self.method(:pack), :after => :install
  end

  def pack
    package.stages.callbacks(:pack).do {
      path = "#{package.to_s(:package)}.pko"

      Dir.chdir package.directory

      FileUtils.mkpath "#{package.directory}/pre"
      FileUtils.mkpath "#{package.directory}/post"
      FileUtils.mkpath "#{package.directory}/selectors"

      if package.fs
        if package.fs.pre
          package.fs.pre.each {|name, file|
            File.write("pre/#{name}", file.content, 0777)
          }
        end

        if package.fs.post
          package.fs.post.each {|name, file|
            File.write("post/#{name}", file.content, 0777)
          }
        end

        if package.fs.selectors
          package.selectors = []

          package.fs.selectors.each {|name, file|
            matches = file.content.match(/^#\s*(.*?):\s*(.*)$/)

            package.selectors << Hash[:name => matches[1], :description => matches[2], :path => name]

            File.write("selectors/#{name}", file.content, 0777)
          }
        end
      end

      Package::Manifest.new(package).save('manifest.xml')

      PKO.pack(path, 'dist/', 'pre/', 'post/', 'selectors/', 'manifest.xml')

      path
    }
  end
end

end; end; end; end
