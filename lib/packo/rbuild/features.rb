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

require 'packo/package/features'

require 'packo/rbuild/feature'

module Packo; module RBuild

class Features < Packo::Package::Features
  Default = Class.new(Hash) {
    def define (name, &block)
      self[name.to_sym] = block
    end
  }.new

  attr_reader :package

  def initialize (package)
    @package = package
    @values  = {}

    yield self if block_given?
  end

  def method_missing (name, *args, &block)
    if block
      @values[name] = Feature.new(@package, name, &block)
    else
      @values[name] || Feature.new(@package, name, false)
    end
  end

  def set (name, &block)
    @values[name.to_sym] = Feature.new(@package, name, &block)
  end

  def get (name)
    @values[name.to_sym] ||= Feature.new(@package, name, false)
  end

  def delete (name)
    @values.delete(name.to_sym)
  end
end

end; end
