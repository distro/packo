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

module Packo; module RBuild

class Dependency < Packo::Package
  def self.parse (text)
    if text.end_with? '!!'
      text[-2, 2] = ''
      type = :runtime
    elsif text.end_with? '!'
      text[-1] = ''
      type = :build
    else
      type = :both
    end

    if matches = text.match(/^([<>~]?=?)/)
      validity = ((matches[1] && !matches[1].empty?) ? matches[1] : nil)
      text.sub!(/^([<>~]?=?)/, '')
    else
      validity = nil
    end

    parsed = Packo::Package.parse(text)

    self.new(parsed.to_hash, validity, type)
  end

  attr_reader :type, :validity

  def initialize (data, validity=nil, type=nil)
    super(data)

    @validity = validity
    @type     = type
  end

  def runtime?; [:runtime, :both].member?(@type) end
  def build?;   [:build, :both].member(@type)    end
  def both?;    @type == :both                   end

  def to_s (name=false)
    if name
      "#{@tags}/#{@name}#{"-#{@version}" if @version}"
    else
      "#{@validity}#{@tags}/#{@name}#{"-#{@version}" if @version}#{"[#{@features}]" if !@features.to_s.empty?}#{"{#{@flavor}}" if !@flavor.to_s.empty?}"
    end
  end
end

end; end
