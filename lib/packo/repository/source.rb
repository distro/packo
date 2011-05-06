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

require 'packo/package'
require 'nokogiri'

module Packo; class Repository

class Source < Repository
  def initialize (data)
    if data[:type] != :source
      raise ArgumentError.new('It has to be a source repository')
    end

    super(data)
  end

  def address
    Nokogiri::XML.parse(File.read("#{self.path}/repository.xml")).xpath('//address').first.text rescue nil
  end

  def each_package (what=[self.path], root=self.path, &block)
    what.select {|what| File.directory? what}.each {|what|
      if File.file? "#{what}/#{File.basename(what)}.rbuild"
        Dir.glob("#{what}/#{File.basename(what)}-*.rbuild").each {|version|
          CLI.info "Parsing #{version.sub("#{self.path}/", '')}" if System.env[:VERBOSE]

          pkg = Packo::Package.new(
            name:    File.basename(what),
            version: version.match(/-(\d.*?)\.rbuild$/)[1]
          )

          begin
            package = Packo.loadPackage(what, pkg)
          rescue LoadError => e
            CLI.warn e.to_s if System.env[:VERBOSE]
          end

          if !package || package.name != pkg.name || package.version != pkg.version
            CLI.warn "Package not found: #{pkg.name}" if System.env[:VERBOSE]
            next
          end

          package.path = version.sub("#{self.path}/", '')

          block.call(package)
        }
      else
        each_package(Dir.entries(what).map {|e|
          "#{what}/#{e}" if e != '.' && e != '..'
        }.compact, root, &block)
      end
    }
  end
end

end; end
