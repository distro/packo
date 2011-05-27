#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free :software => you can redistribute it and/or modify
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

require 'packo/extensions'
require 'packo/environment'
require 'packo/host'

module Packo

System = Class.new {
  attr_reader :environment, :host

  def environment!; @environmentClean end

  alias env environment
  alias env! environment!

  def initialize
    @environment      = Environment.new
    @environmentClean = Environment.new(nil, true)

    @host = Host.new(env!) rescue Host.parse(RUBY_PLATFORM)

    if env[:DEBUG] && env[:DEBUG] != '0'
      begin
        require 'ap'
      rescue LoadError
      end
    end
  end

  def has? (package, options={})
    require 'packo/models'

    if package.is_a?(Package::Tags) || package.is_a?(Array)
      expression = "[#{package.join(' && ')}]"
    elsif package.is_a?(Package)
      expression = package.to_s(:whole)
    else
      expression = package.to_s
    end

    !Models::InstalledPackage.search(expression, options).empty?
  end
}.new

end
