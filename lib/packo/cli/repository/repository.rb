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

module Packo; module CLI; class Repository < Thor; module Helpers

module Repository
  def self.wrap (model)
    case model.type
      when :binary;  Binary.new(model)
      when :source;  Source.new(model)
      when :virtual; Virtual.new(model)
    end
  end

  def model; @model      end
  def type;  @model.type end
  def name;  @model.name end
  def uri;   @model.uri  end
  def path;  @model.path end
end

require 'packo/cli/repository/binary'
require 'packo/cli/repository/source'
require 'packo/cli/repository/virtual'

end; end; end; end
