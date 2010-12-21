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
require 'packo/rbuild'

module Packo; module CLI; class Repository < Thor; module Helpers

class Source < Packo::Repository::Source
  include Packo::Models
  include Helpers::Repository

  def initialize (model)
    @model = model
  end

  def populate
    self.generate

    self.packages.each {|package|
      pkg = repository.packages.first_or_create(
        :repo => repository,

        :tags_hashed => package.tags.hashed,
        :name        => package.name,
        :version     => package.version,
        :slot        => package.slot,
        :revision    => package.revision
      )

      pkg.update(
        :description => package.description,
        :homepage    => [package.homepage].flatten.join(' '),
        :license     => [package.license].flatten.join(' '),

        :maintainer => package.maintainer
      )

      package.tags.each {|tag|
        pkg.tags.first_or_create(:name => tag.to_s)
      }

      pkg.data.update(
        :path => File.dirname(version.sub("#{self.path}/", ''))
      )

      package.features.each {|f|
        feature = pkg.data.features.first_or_create(
          :source => pkg.data,
          :name   => f.name
        )

        feature.update(
          :description => f.description,
          :enabled     => f.enabled?
        )
      }
    }
  end
end

end; end; end; end
