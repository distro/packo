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

require 'packo/feature'

module Packo

class Features
  attr_reader :package

  def initialize (package)
    @package = package
    @features = {}
  end

  def method_missing (name, *args, &block)
    if block
      @features[name] = Feature.new(@package, name, &block)
    else
      @features[name] || Feature.new(@package, name, false)
    end
  end

  def set (name, &block)
    @features[name.to_sym] = Feature.new(@package, name.to_sym, &block)
  end

  def get (name)
    @features[name.to_sym] || Feature.new(@package, name.to_sym, false)
  end

  def delete (name)
    @features.delete(name.to_sym)
  end

  def each (&block)
    @features.each_value {|feature|
      block.call feature
    }
  end
  
  def owner= (value)
    @package = value

    @features.each_value {|feature|
      feature.owner = value
    }
  end

  def to_s (pack=false)
    if pack
      @features.select {|name, feature| feature.enabled?}.map {|item| item[0]}.join('-')
    else
      @features.sort {|a, b|
        if a[1].enabled? && b[1].enabled?
          0
        elsif a[1].enabled? && !b[1].enabled?
          -1
        else
          1
        end
      }.to_a.map {|feature| (feature[1].enabled? ? '' : '-') + feature[0].to_s}.join(',')
    end
  end
end

end
