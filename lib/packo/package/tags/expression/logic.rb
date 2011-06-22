#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

module Packo; class Package; class Tags < Array; class Expression

class Logic
  attr_reader :type

  def initialize (what)
    @type = case what
      when '!',  /not/i then :not
      when '&&', /and/i then :and
      when '||', /or/i  then :or
    end

    raise SyntaxError.new('Invalid logical operator') unless @type
  end

  def evaluate (a, b=nil)
    case @type
      when :not; !a
      when :and; !!(a && b)
      when :or;  !!(a || b)
    end
  end

  def inspect
    self.type.to_s.upcase
  end
end

end; end; end; end
