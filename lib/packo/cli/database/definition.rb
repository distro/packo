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

module Packo; module CLI; class Database < Thor; module Helpers

class Definition
  def self.parse (data)
    Definition.new(JSON.parse(data))
  end

  def self.open (path)
    data = File.read(path)

    Definition.parse(LZMA.decompress(data) rescue data)
  end

  def initialize (data)
    self.import(data)
  end

  def import (data)

  end

  def commit
    query = ''
    
    query << 'BEGIN;'

    query << 'COMMIT;'

    database.execute(query)
  end
end

end; end; end; end
