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

require 'packo/models'
require 'packo/rbuild'

require 'packo/do/repository/repository'

module Packo; class Do; class Repository; module Helpers

class Source < Packo::Repository::Source
	include Packo::Models
	include Helpers::Repository

	def initialize (model)
		super(model.to_hash.merge(model: model))
	end

	def populate
		packages.each {|package|
			pkg = model.packages.first_or_create(
				repo: model,
				type: Models::Repository::Package::Source,

				tags_hashed: package.tags.hashed,
				name:        package.name,
				version:     package.version,
				slot:        package.slot,
				revision:    package.revision
			)

			pkg.update(
				description: package.description,
				homepage:    [package.homepage].flatten.join(' '),
				license:     [package.license].flatten.join(' '),

				maintainer: package.maintainer
			)

			package.tags.each {|tag|
				pkg.tags << Tag.first_or_create(name: tag.to_s)
			}

			pkg.update(
				path: File.dirname(package.path)[(path.length + 1) .. -1]
			)

			package.features.each {|f|
				feature = pkg.features.first_or_create(
					name: f.name
				)

				feature.update(
					description: f.description,
					enabled:     f.enabled?
				)
			}

			package.flavor.each {|f|
				next if %w(vanilla documentation headers debug).member?(f.name.to_s)

				flavor = pkg.flavor.first_or_create(
					name: f.name
				)

				flavor.update(
					description: f.description,
					enabled:     f.enabled?
				)
			}

			pkg.save
		}
	end
end

end; end; end; end
