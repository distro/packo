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

module Packo

module Modules

module Packaging

class PKO < Module
  def initialize (package)
    super(package)

    package.stages.add :pack, self.method(:pack), :after => :install
  end

  def pack
    if (error = package.stages.call(:pack).find {|result| result.is_a? Exception})
      Packo.debug error
      return
    end

    Dir.chdir package.directory

    file = File.new('package.xml', 'w')
    file.write(package.to_xml)
    file.close

    FileUtils.mkpath "#{package.directory}/pre"
    package.pre.each {|pre|
      file = File.new("pre/#{pre[:name]}", 'w', 0777)
      file.write(pre[:content])
      file.close
    }

    FileUtils.mkpath "#{package.directory}/post"
    package.post.each {|post|
      file = File.new("post/#{post[:name]}", 'w', 0777)
      file.write(post[:content])
      file.close
    }

    name = "#{package.to_s(true)}.pko"

    Packo.sh 'tar', 'cJf', name, 'dist/', 'pre/', 'post/', 'package.xml'

    package.stages.call(:packed, "#{package.directory}/#{name}")
  end
end

end

end

end
