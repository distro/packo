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

module Packo; module RBuild; module Modules; module Fetching

class Bazaar < Module
  def initialize (package)
    super(package)

    package.avoid [Fetcher, Unpacker]

    package.stages.add :fetch, self.method(:fetch), after: :beginning

    package.after :initialize do
      package.dependencies << 'vcs/bzr!'
    end
  end

  def finalize
    package.stages.delete :fetch, self.method(:fetch)
  end

  def bzr (*args)
    Packo.sh 'bzr', *args
  end

  def fetch
    package.stages.callbacks(:fetch).do {
      package.clean!
      package.create!

      branch     = package.bazaar[:branch].to_s.interpolate(package) rescue nil
      repository = package.bazaar[:repository].to_s.interpolate(package) rescue nil

      Do.rm package.workdir

      if repository && branch
        bzr :checkout, '--lightweight', "#{repository}/#{branch}", package.workdir
      else
        bzr :checkout, '--lightweight', repository || branch, package.workdir
      end

      Do.cd package.workdir
    }
  end
end

end; end; end; end
