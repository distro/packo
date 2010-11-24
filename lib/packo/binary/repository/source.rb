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

require 'packo/binary/helpers'

module Packo; module Binary; class Repository

class Source < Repository
  include Packo::Binary::Helpers

  def initialize (repo)
    super(repo)
  end

  def populate (what=[self.path], root=self.path)
    last = nil

    what.select {|what| File.directory? what}.each {|what|
      if File.file? "#{what}/#{File.basename(what)}.rbuild"
        Dir.glob("#{what}/#{File.basename(what)}-*.{rbuild,xml}").each {|version|
          package = Packo::Package.new(
            :name       => File.basename(what),
            :version    => version.match(/-(\d.*?)\.(rbuild|xml)$/)[1]
          )

          begin
            loadPackage(what, package)
          rescue LoadError => e
            warn e.to_s if Packo::Environment[:VERBOSE]
          end

          package = Packo::RBuild::Packages[package.to_s]

          if !package
            warn "Package not found: #{File.basename(what)}" if Packo::Environment[:VERBOSE]
            next
          end

          pkg = repository.packages.first_or_new(
            :tags     => package.tags.hash,
            :name     => package.name,
            :version  => package.version,
            :slot     => package.slot,
            :revision => package.revision,

            :description => package.description,
            :homepage    => [package.homepage].flatten.join(' '),
            :license     => [package.license].flatten.join(' ')
          )

          package.tags.each {|tag|
            Tagging::Tagged.create(
              :package => package.id,
              :tag     => Tagging::Tag.first_or_create(:name => tag)
            )
          }

          package.features.each {|feature|
            pkg.features.new(
              :name        => feature.name,
              :description => feature.description,
              :enabled     => feature.enabled?
            )
          }

          pkg.save

          Packo::Packages.delete package.to_s(:name)
          Packo::Packages.delete package.to_s
        }
      else
        populate(Dir.entries(what).map {|e|
          "#{what}/#{e}" if e != '.' && e != '..'
        }.compact, root)
      end
    }
  end
end

end; end; end
