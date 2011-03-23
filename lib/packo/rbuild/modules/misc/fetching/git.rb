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

module Packo; module RBuild; module Modules; module Misc; module Fetching

class Git < Module
  def initialize (package)
    super(package)

    package.avoid [Fetcher, Unpacker]

    package.stages.add :fetch, self.method(:fetch), :after => :beginning
  end

  def finalize
    package.stages.delete :fetch, self.method(:fetch)
  end

  def fetch
    package.stages.callbacks(:fetch).do {
      whole, url, branch, commit = package.source.match(%r[^(\w+://.*?)(?::(.*?))?(?:@(.*?))?$]).to_a

      package.clean!
      package.create!

      options = []
      options << '--branch' << branch if branch
      options << '--depth'  << '1'    if !commit

      Packo.sh 'git', 'clone', *options, url, package.workdir

      Do.cd package.workdir
    }
  end
end

end; end; end; end; end
