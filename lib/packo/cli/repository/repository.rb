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

module Packo; module CLI; class Repository; module Helpers

class Repository
  def self.wrap (repo)
    case repo.type
      when :binary;  Binary.new(repo)
      when :source;  Source.new(repo)
      when :virtual; Virtual.new(repo)
    end
  end

  attr_reader :repository

  def initialize (repo)
    repo.save

    @repository = repo
  end

  def type; @repository.type end
  def name; @repository.name end
  def uri;  @repository.uri  end
  def path; @repository.path end
end

require 'packo/cli/repository/binary'
require 'packo/cli/repository/source'
require 'packo/cli/repository/virtual'

end; end; end; end
