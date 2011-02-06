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

require 'packo/package/feature'

module Packo; module RBuild

class Feature < Packo::Package::Feature
  include Stages::Callable

  attr_reader :package, :name, :block, :dependencies

  def initialize (package, name, enabled=false, &block)
    super(name, enabled)

    @package      = package
    @dependencies = []

    if Features::Default[self.name.to_sym]
      self.instance_exec(self, &Features::Default[self.name.to_sym])
    end

    self.do(&block)
  end

  def do (&block)
    self.instance_exec(self, &block) if block
    self
  end

  def needs (*names)
    if names.first == :not
      names[1, names.length].each {|name|
        @dependencies.delete(name)
      }
    else
      @dependencies = @dependencies.concat(names).flatten.compact.uniq
    end
  end

  def method_missing (id, *args, &block)
    @package.send id, *args, &block
  end
end

end; end
