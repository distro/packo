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

require 'packo/package/flavor'

require 'packo/rbuild/feature'

module Packo; module RBuild

class Flavor < Packo::Package::Flavor
  Default = Class.new(Hash) {
    def define (name, &block)
      (self[name.to_sym] ||= []) << block
    end
  }.new

  attr_reader :package

  def initialize (package, values={})
    super(values)

    @package = package

    yield self if block_given?
  end

  def method_missing (id, *args, &block)
    case id.to_s
      when /^(.+?)\?$/    then (@values[$1.to_sym] ||  Feature.new(@package, $1, false)).enabled?
      when /^not_(.+?)!$/ then (@values[$1.to_sym] ||= Feature.new(@package, $1, false)).disable!
      when /^(.+?)!$/     then (@values[$1.to_sym] ||= Feature.new(@package, $1, false)).enable!
      when /^(.+?)$/      then (@values[$1.to_sym] ||= Feature.new(@package, $1, false)).do(&block)
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

  def needs (expression=nil)
    expression ? @needs = expression : @needs
  end
end

end; end
