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

require 'packo/environment'
require 'packo/rbuild'

module Packo; module Binary

module Helpers
  def colorize (text, fg, bg=nil, attr=nil)
    Packo.colorize(text, fg, bg, attr)
  end

  def info (text)
    Packo.info(text)
  end

  alias _info info

  def warn (text)
    Packo.warn(text)
  end

  alias _warn warn

  def fatal (text)
    Packo.fatal(text)
  end

  alias _fatal fatal

  def loadPackage (path, package)
    options = {
      :before => 'module ::Packo::RBuild;',
      :after  => ';end'
    }

    if File.exists?("#{path}/digest.xml") && (digest = Nokogiri::XML.parse(File.read("#{path}/digest.xml")))
      features = digest.xpath("//build[@version = '#{package.version}'][@slot = '#{package.slot}']/features").first

      if features
        features.text.split(' ').each {|feature|
          next if RBuild::Features::Default[feature.to_sym]

          begin
            Packo.load "#{System.env[:PROFILE]}/features/#{feature}", options
          rescue LoadError
          rescue Exception => e
            warn "Something went wrong while loading #{feature} feature."
            Packo.debug e
          end
        }
      end
    end

    Packo.load "#{path}/#{package.name}.rbuild", options

    if (pkg = RBuild::Package.last) && (tmp = File.read("#{path}/#{package.name}.rbuild").split(/^__END__$/)).length > 1
      pkg.filesystem.parse(tmp.last.lstrip)
    end

    Packo.load "#{path}/#{package.name}-#{package.version}.rbuild", options

    if RBuild::Package.last.name == package.name && RBuild::Package.last.version == package.version
      RBuild::Package.last.filesystem.merge!(pkg.filesystem)

      if (tmp = File.read("#{path}/#{package.name}-#{package.version}.rbuild").split(/^__END__$/)).length > 1
        RBuild::Package.last.filesystem.parse(tmp.last.lstrip)
      end

      return RBuild::Package.last
    end
  end
end

end; end
