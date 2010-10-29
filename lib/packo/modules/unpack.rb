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

require 'packo/module'

module Packo

module Modules

class Unpack < Module
  def initialize (package)
    super(package)

    Packo.env('WORKDIR', '/tmp') if !Packo.env('WORKDIR')

    package.stages.add :unpack, self.method(:unpack), :after => :fetch, :strict => true
  end

  def unpack
    puts package.distfiles.inspect

    package.distfiles.each {|file|
      if (error = package.stages.call(:unpack, file).find {|result| result.is_a? Exception})
        puts error.to_s
        return
      end

      Packo.sh 'tar', 'xf', file, '-k', '-C', Packo.env('WORKDIR')

      if (error = package.stages.call(:unpacked, file).find {|result| result.is_a? Exception})
        puts error.to_s
        return
      end
    }

    Dir.chdir "#{Packo.env('WORKDIR')}/#{Packo.interpolate(package.directory, self)}"
  end
end

end

end
