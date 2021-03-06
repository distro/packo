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

require 'packo/package'

module Packo; class Repository

class Source < Repository
	def initialize (data)
		if data[:type] != :source
			raise ArgumentError.new('It has to be a source repository')
		end

		super(data)
	end

	def location
		Location[YAML.parse_file("#{path}/repository.yml").transform['location']]
	end

	def each_package (what = [path], &block)
		what.select {|what| File.directory? what}.each {|what|
			if File.file? "#{what}/#{File.basename(what)}.rbuild"
				Dir.glob("#{what}/#{File.basename(what)}-*.rbuild").each {|version|
					CLI.info "Parsing #{version.sub("#{path}/", '')}" if System.env[:VERBOSE]

					begin
						package = RBuild::Package.load(version)
					rescue LoadError => e
						CLI.warn e.to_s if System.env[:VERBOSE]
					end

					if !package
						CLI.warn "Package not found in #{version}" if System.env[:VERBOSE]
						next
					end

					block.call(package)
				}
			end

			each_package(Dir.entries(what).map {|e|
				"#{what}/#{e}" if e != '.' && e != '..' && e != 'data'
			}.compact, &block)
		}
	end
end

end; end
