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

require 'uri'

module Packo; class Do; class Repository

class Remote
	module Model
		def self.add (name, uri, path, description=nil)
			require 'packo/models'

			remote = Models::Repository::Remote.first_or_create(name: name)
			remote.update(
				uri:  uri,
				path: path,
				description: description
			)

			YAML.parse_file(path).transform['repositories'].each {|type, data|
				data.each {|piece|
					remote.pieces.first_or_create(type: type, name: piece['name']).update(
						description: piece['description'],
						location:    piece['location']
					)
				}
			}

			remote
		end

		def self.delete (name)
			Models::Repository::Remote.first(name: name).destroy
		end
	end

	def self.add (uri)
		uri = URI.parse(uri)

		if uri.scheme.nil? || uri.scheme == 'file'
			uri = URI.parse(File.realpath(uri.path))
		end

		path = "#{System.env[:MAIN_PATH]}/repositories/remotes/#{File.basename(uri.path)}"

		FileUtils.mkpath(File.dirname(path))

		content = open(uri.to_s).read
		data    = YAML.parse(content).transform

		Models.transaction {
			File.write(path, content)

			Model.add(data['name'], uri, path, data['description'])
		}
	end

	def self.delete (remote)
		FileUtils.rm_rf remote.path, secure: true

		Models.transaction {
			remote.destroy
		}
	end

	def self.update (remote)
		uri = remote.uri.to_s

		return false if (content = open(uri).read) == File.read(remote.path)

		delete(remote)
		add(uri)
	end

	def self.get (name)
		require 'packo/models'

		what = Packo::Repository.parse(name)

		Models::Repository::Remote::Piece.first(type: what.type, name: what.name) rescue nil
	end
end

end; end; end
