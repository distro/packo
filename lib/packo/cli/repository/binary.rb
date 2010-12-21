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

require 'packo/models'

module Packo; module CLI; class Repository < Thor; module Helpers

class Binary < Packo::Repository::Binary
  include Packo::Models
  include Helpers::Repository

  def initialize (model)
    @model = model
  end

  def populate
    self.generate

    self.packages.each {|package|
      pkg = repository.packages.first_or_create(
        :repo => @model,

        :tags_hashed => package.tags.hashed,
        :name        => package.name,
        :version     => package.version,
        :slot        => package.slot,
        :revision    => package.revision
      )

      pkg.update(
        :features => package.features,

        :description => package.description,
        :homepage    => package.homepage,
        :license     => package.license,

        :maintainer => package.maintainer
      )

      package.tags.each {|tag|
        pkg.tags.first_or_create(:name => tag.to_s)
      }

      package.builds.each {|build|
        bld = pkg.data.builds.first_or_create(
          :flavor   => build.flavor,
          :features => build.features
        )

        bld.update(
          :digest => build.digest
        )
      }
    }
  end
end

end; end; end; end
