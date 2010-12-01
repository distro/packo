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

module Packo; module RBuild; module Modules; module Misc

class Unpack < Module
  def self.do (path, to)
    compression = case File.extname(path)
      when '.xz'; 'J'
      else        ''
    end

    FileUtils.mkpath(to) rescue nil

    Packo.sh 'tar', "x#{compression}f", path, '-k', '-C', to
  end

  def initialize (package)
    super(package)

    package.stages.add :unpack, self.method(:unpack), :after => :fetch, :strict => true

    before :initialize do |package|
      package.define_singleton_method :unpack, &Unpack.method(:do)
    end
  end

  def unpack
    package.stages.callbacks(:unpack).do {
      Unpack.do file, Packo.interpolate('#{package.directory}/work', self)

      Dir.chdir "#{package.workdir}/#{package.name}-#{package.version}" rescue nil
    }
  end
end

end; end; end; end
