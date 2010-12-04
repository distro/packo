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

class Blocker < Packo::Package
  def self.parse (text)
    runtime = true

    if text.end_with? '!'
      text[-1] = ''
      runtime = false
    end

    if matches = text.match(/^([<>]?=?)/)
      validity = ((matches[1] && !matches[1].empty?) ? matches[1] : nil)
      text.sub!(/^([<>]?=?)/, '')
    else
      validity = nil
    end

    parsed = Packo::Package.parse(text)

    self.new(parsed.to_hash, validity, runtime)
  end

  def initialize (data, validity=nil, runtime=true)
    super(data)

    @validity = validity
    @runtime  = runtime
  end

  def runtime?; @runtime end

  def to_s (name=false)
    if name
      "#{@tags}/#{@name}#{"-#{@version}" if @version}"
    else
      features = @features.to_a.sort {|a, b|
        if a.enabled? && b.enabled?     ;  0
        elsif a.enabled? && !b.enabled? ; -1
        else                            ;  1
        end
      }.map {|feature|
        (feature.enabled? ? '' : '-') + feature.name.to_s
      }.join(',')

      flavor = @flavor.to_a.map {|f|
        f.name.to_s
      }.sort

      "#{@validity}#{@tags}/#{@name}#{"-#{@version}" if @version}#{"[#{features}]" if !features.empty?}#{"{#{flavor}}" if !flavor.empty?}"
    end
  end
end

end; end
