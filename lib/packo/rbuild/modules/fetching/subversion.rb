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

module Packo; module RBuild; module Modules; module Fetching

class Subversion < Module
  def initialize (package)
    super(package)

    package.avoid [Fetcher, Unpacker]

    package.stages.add :fetch, self.method(:fetch), after: :beginning

    package.after :initialize do
      package.dependencies << 'vcs/subversion!'
    end
  end

  def finalize
    package.stages.delete :fetch, self.method(:fetch)
  end

  def svn (*args)
    Packo.sh 'svn', *args
  end

  def fetch
    package.stages.callbacks(:fetch).do {
      package.clean!
      package.create!

      repository = package.subversion[:repository].to_s.interpolate(package)

      options = []

      if package.subversion[:revision]
        options << '--revision' << package.subversion[:revision].to_s.interpolate(package)
      end

      if package.subversion[:tag]
        svn 'checkout', *options, "#{repository}/tags/#{package.subversion[:tag].to_s.interpolate(package)}", package.workdir
      elsif package.subversion[:branch]
        svn 'checkout', *options, "#{repository}/branches/#{package.subversion[:branch].to_s.interpolate(package)}", package.workdir
      else
        svn 'checkout', *options, "#{repository}/trunk", package.workdir
      end

      Do.cd package.workdir
    }
  end
end

end; end; end; end
