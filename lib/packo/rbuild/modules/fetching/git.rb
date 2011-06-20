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

class Git < Module
  def self.do (*args)
    Packo.sh 'git', *args
  end

  def self.valid? (path)
    Do.cd path do
      Git.do(:status, silent: true, throw: false) == 0
    end
  end

  def self.fetch (location, path)
    if Git.valid?(path)
      Git.update(path)

      Do.cd path do
        return true if begin
          if location.branch || location.commit || location.tag
            Git.do :checkout, location.branch || location.commit || location.tag, silent: true
          else
            Git.do :checkout, :master, silent: true
          end

          true
        rescue
          false
        end
      end
    end
    
    Do.rm path

    options = []

    options << '--branch' << location.branch if location.branch
    options << '--depth'  << '1' unless location.commit || location.tag

    Git.do :clone, *options, location.repository, path

    Do.cd path do
      if location.commit || location.tag
        Git.do :checkout, location.commit || location.tag, silent: true
      end

      Git.do :submodule, :init throw: false
      Git.do :submodule, :update, throw: false
    end

    true
  end

  def self.update (path)
    raise ArgumentError.new 'The passed path is not a git repository' unless Git.valid?(path)

    Do.cd path do
      Git.do(:reset, '--hard', silent: true, throw: false) == 0 && Git.do(:pull, catch: true).strip != 'Already up-to-date.'
    end
  end

  def initialize (package)
    super(package)

    package.avoid [Fetcher, Unpacker]

    package.stages.add :fetch, self.method(:fetch), after: :beginning

    package.after :initialize do
      package.dependencies << 'vcs/git!'
    end
  end

  def finalize
    package.stages.delete :fetch, self.method(:fetch)
  end

  def fetch
    package.callbacks(:fetch).do {
      package.source.to_hash.each {|name, value|
        package.source[name] = value.to_s.interpolate(package)
      }

      Git.fetch package.source, package.workdir

      Do.cd package.workdir
    }
  end
end

end; end; end; end
