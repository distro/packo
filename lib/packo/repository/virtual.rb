#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free :software => you can redistribute it and/or modify
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

require 'fffs'

require 'packo/package'

module Packo; class Repository

class Virtual < Repository
  attr_reader :filesystem

  def initialize (data, &block)
    if data[:type] != :virtual
      raise ArgumentError.new('It has to be a virtual repository')
    end

    super(data)

    @filesystem = FFFS::FileSystem.new

    self.do(File.read(data[:path])) if data[:path]
    self.do(&block) if block
  end

  def do (data=nil, &block)
    repository = self

    if data
      if (tmp = data.split(/^__END__$/)).length > 1
        @filesystem.parse(tmp.last.lstrip)
        data = tmp.first
      end

      self.instance_eval(data) if data
    end

    if block
      self.instance_eval(&block)
    end

    self
  end

  def install (package)
    false
  end

  def uninstall (package)
    true
  end
end

end; end
