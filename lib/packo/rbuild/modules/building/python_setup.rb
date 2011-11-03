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

module Packo; module RBuild; module Modules; module Building

class PythonSetup < Module
	def initialize (package)
		super(package)

		package.use -package.stages.owner_of(:compile)

		package.stages.add :configure, method(:configure), after: :fetch
		package.stages.add :compile,   method(:compile),   after: :configure
		package.stages.add :install,   method(:install),   after: :compile

		package.before :initialize do
			package.dependencies << 'development/utility/python!'
		end

		package.setup = Module::Helper.for(package) {
			def initialize (package)
				super(package)
			end

			def do (*args)
				package.environment.sandbox {
					Packo.sh "python#{@version}", 'setup.py', *args
				}
			end

			def version (ver)
				@version ||= ver
			end
		}
	end

	def finalize
		package.stages.delete :configure
		package.stages.delete :compile
		package.stages.delete :install
	end

	def configure
		@configuration = []

		package.callbacks(:configure).do(@configuration)
	end

	def compile
		package.callbacks(:compile).do(@configuration) {
			package.setup.do :build
		}
	end

	def install
		package.callbacks(:install).do(@configuration)
	end
end

end; end; end; end
