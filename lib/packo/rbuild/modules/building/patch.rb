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

require 'tempfile'

module Packo; module RBuild; module Modules; module Building

class Patch < Module
  def initialize (package)
    super(package)

    package.stages.add :patch, self.method(:patch), :after => :unpack, :strict => true

    before :initialize do |package|
      package.define_singleton_method :patch do |patch, options={}|
        if patch.is_a?(FFFS::File) || options[:stream]
          temp = Tempfile.new('patch')
          temp.write patch.to_s
          temp.close

          Packo.sh "patch -f -p#{options[:level] || 0} < '#{temp.path}'"

          temp.unlink
        else
          Packo.sh "patch -f -p#{options[:level] || 0} < '#{patch}'"
        end
      end
    end
  end

  def patch
    package.stages.callbacks(:patch).do(package) {
      next unless packages.fs.patches.is_a?(Directory)

      _patch(package.fs.patches)
    }
  end

  private
    
    def _patch (file)
      if file.is_a?(Directory)
        file.sort.each {|(name, file)|
          Do.cd(file.name) {
            _patch(file)
          }
        }
      else
        package.patch(file) rescue nil
      end
    end
end

end; end; end; end
