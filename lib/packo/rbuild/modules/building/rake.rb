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

module Packo; module RBuild; module Modules; module Building

class Rake < Module
  def initialize (package)
    super(package)

    package.avoid package.stages.owner_of(:compile)

    package.stages.add :configure, self.method(:configure), :after => :fetch
    package.stages.add :compile,   self.method(:compile),   :after => :configure
    package.stages.add :install,   self.method(:install),   :after => :compile

    package.after :initialize do
      package.environment[:RUBYOPT] = ''

      package.dependencies << 'interpreter/ruby!'
    end

    package.rake = Class.new(Module::Helper) {
      attr_accessor :configuration

      def initialize (package)
        super(package)

        @configuration = Autotools::Configuration.new(package)
      end

      def do (*args)
        package.environment.sandbox {
          Packo.sh 'rake', *args
        }
      end

      def install (*args)
        self.do 'install', *args
      end

      def version (name, slot=nil)
        slot ? @versions[name.to_sym] = slot : @versions[name.to_sym]
      end
    }.new(package)
  end

  def finalize
    package.stages.delete :configure, self.method(:configure)
    package.stages.delete :compile,   self.method(:compile)
    package.stages.delete :install,   self.method(:install)
  end

  def configure
    @configuration = package.rake.configuration

    package.callbacks(:configure).do(@configuration)
  end

  def compile
    package.callbacks(:compile).do(@configuration) {
      package.rake.do
    }
  end

  def install
    package.callbacks(:install).do(@configuration) {
      package.rake.install
    }
  end
end

end; end; end; end
