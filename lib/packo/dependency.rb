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

module Packo

class Dependency
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

    self.new(parsed.name, parsed.categories, parsed.version, parsed.features, parsed.flavors, validity, runtime)
  end

  attr_reader :name, :categories, :version, :features, :flavors, :validity

  def initialize (name, categories, version, features, flavors, validity=nil, runtime=true)
    @name       = name
    @categories = categories
    @version    = (!(version || '').empty?) ? Versionomy.parse(version) : nil
    @features   = features
    @flavors    = flavors
    @validity   = validity
    @runtime    = runtime
  end

  def runtime?; @runtime end

  def to_s (name=false)
    if name
      "#{(@categories + [@name]).join('/')}#{"-#{@version}" if @version}"
    else
      features = @features.sort {|a, b|
        if a[1] && b[1]
          0
        elsif a[1] && !b[1]
          -1
        else
          1
        end
      }.to_a.map {|feature| (feature[1] ? '' : '-') + feature[0].to_s}.join(',')

      flavors = @flavors.sort

      "#{@validity}#{(@categories + [@name]).join('/')}#{"-#{@version}" if @version}#{"[#{features}]" if !features.empty?}#{"{#{flavors}}" if !flavors.empty?}"
    end
  end
end

end
