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

require 'digest/sha1'

module Packo; class Package

class Tags < Array
  def self.parse (value)
    value.is_a?(Array) ?
      Tags.new(value) :
      Tags.new(value.to_s.split('/'))
  end

  def initialize (*tags)
    tags.flatten.each {|tag|
      self << tag.to_s
    }
  end

  def == (tags)
    self.to_a.sort == tags.to_a.sort
  end

  def hashed
    Digest::SHA1.hexdigest(self.sort.join('/'))
  end

  def hash
    self.sort.join('/').hash
  end

  def to_s (minimized=false)
    minimized ?
      self.sort.map {|t| t[0]}.join :
      self.join('/')
  end
end

end; end
