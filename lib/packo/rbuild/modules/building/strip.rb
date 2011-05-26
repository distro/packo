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

class Strip < Module
  def initialize (package)
    super(package)

    package.stages.add :strip, self.method(:strip), before: :pack
  end

  def strip
    package.callbacks(:strip).do {
      next if package.env[:NO_STRIP]

      Find.find(package.distdir) {|file|
        next unless File.file?(file)

        Packo.sh 'strip', file, silent: true rescue nil
      }
    }
  end
end

end; end; end; end

