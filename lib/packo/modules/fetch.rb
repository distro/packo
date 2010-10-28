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

require 'packo/module'

module Packo

module Modules

class Fetch < Module
  def initialize (package)
    super(package)

    package.stages.add :fetch,    self.method(:fetch),    :after => :dependencies
    package.stages.add :fetching, self.method(:fetching), :after => :fetch
    package.stages.add :fetched,  self.method(:fetched),  :after => :fetching
  end

  def fetch
  end

  def fetching
    version = package.version

    source = eval('"' + package.source + '"') rescue nil

    package.stages.call :fetch, source

    `wget -c -O "/tmp/#{File.basename(source)}" "#{source}"`
  end

  def fetched
  end
end

end

end
