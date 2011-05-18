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

require 'colorb'

module Packo

class Service

module CLI
  def self.info (text)
    text.strip.lines.each {|line|
      puts "#{'*'.green.bold} #{line.strip}"
    }
  end

  def self.warn (text)
    text.strip.lines.each {|line|
      puts "#{'*'.yellow.bold} #{line.strip}"
    }
  end

  def self.fatal (text)
    text.strip.lines.each {|line|
      puts "#{'*'.red} #{line.strip}"
    }
  end

  def self.message (text, options={})
    case options[:type] || :info
      when :info  then print "#{'*'.green} "
      when :warn  then print "#{'*'.yellow} "
      when :fatal then print "#{'*'.red} "
    end

    print text
    STDOUT.flush

    begin
      if yield
        puts " #{(options[:good] || '^_^').green}"
      else
        raise
      end
    rescue Exception => e
      puts " #{(options[:bad] || ';_;').red}"
      
      CLI.fatal e.message
    end
  end
end

end

end
