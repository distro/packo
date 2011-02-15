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

module Packo; module RBuild; module Modules; module Building

class Patch < Module
  def self.do (patch, options={})
    begin
      if patch.is_a?(FFFS::File) || options[:stream]
        temp = Tempfile.new('patch')
        temp.write patch.to_s
        temp.close

        Packo.sh "patch -f -p#{options[:level] || 0} < '#{temp.path}'"

        temp.unlink
      else
        Packo.sh "patch -f -p#{options[:level] || 0} < '#{patch}'"
      end
    rescue Exception => e
      Packo.debug e
      return false
    end

    return true
  end

  def initialize (package)
    super(package)

    package.stages.add :patch, self.method(:patch), :after => :unpack, :strict => true

    before :initialize do |package|
      package.define_singleton_method :patch, &Patch.method(:do)
    end
  end

  def finalize
    package.stages.delete :patch, self.method(:patch)
  end

  def patch
    package.stages.callbacks(:patch).do(package) {
      package.filesystem.patches.each {|name, file|
        _patch(file)
      }
    }
  end

  private
    
  def _patch (what)
    if what.is_a?(FFFS::Directory)
      what.sort.each {|(name, file)|
        Do.cd(what.name) {
          _patch(file)
        }
      }
    else
      package.patch(what) rescue nil
    end
  end
end

end; end; end; end
