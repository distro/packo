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

require 'packo'
require 'colorb'

module Packo

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

  def self.confirm? (query, default=true)
    $stdout.print "#{query} [#{default ? 'YES/no' : 'yes/NO'}] "

    case $stdin.gets.strip
      when /^(true|y(es)?|1)$/i then true
      when /^(false|no?|0)$/i   then false
      else                           !!default
    end
  end

  def self.choice (list=nil, query='The choice is yours')
    array = if list.is_a?(Array)
      list = Hash[list.each_with_index.map {|v, i|
        [i + 1, v]
      }]

      true
    else
      false
    end

    if list.is_a?(Hash)
      list = Hash[list.map {|i, v| [i.to_s, v] }]
    else
      return nil
    end

    max = list.keys.map {|x|
      x.to_s.size
    }.max

    $stdout.puts "#{query}:"
    list.each {|index, value|
      $stdout.puts "  #{index.rjust(max)}: #{value}"
    }
    $stdout.print "Choice: "

    choice = $stdin.gets.strip

    if list.keys.include?(choice)
      array ? choice.to_i - 1 : choice
    else
      nil
    end
  end
end

end

[:INT, :QUIT, :ABRT, :TERM, :TSTP].each {|sig|
  trap sig do
    if defined?(Packo::Models)
      Packo::Models.transactions.each {|t| t.rollback}
    end

    puts 'Aborting.'

    Process.exit! 1
  end
}
