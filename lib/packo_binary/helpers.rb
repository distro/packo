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

require 'packo/environment'

module PackoBinary

module Helpers
  def colorize (text, fg, bg=nil, attr=nil)
    return text if Packo::Environment[:NO_COLORS]

    colors = {
      :DEFAULT => 9,
      nil      => 9,

      :BLACK   => 0,
      :RED     => 1,
      :GREEN   => 2,
      :YELLOW  => 3,
      :BLUE    => 4,
      :MAGENTA => 5,
      :CYAN    => 6,
      :WHITE   => 7
    }

    attributes = {
      :DEFAULT => 0,
      nil      => 0,

      :BOLD      => 1,
      :UNDERLINE => 4,
      :BLINK     => 5,
      :REVERSE   => 7
    }

    "\e[#{attributes[attr]};3#{colors[fg]};4#{colors[bg]}m#{text}\e[0m"
  end

  def info (text)
    puts "#{colorize('*', :GREEN, :DEFAULT, :BOLD)} #{text}"
  end

  alias _info info

  def warn (text)
    puts "#{colorize('*', :YELLOW, :DEFAULT, :BOLD)} #{text}"
  end

  alias _warn warn

  def fatal (text)
    puts "#{colorize('*', :RED)} #{text}"
  end

  alias _fatal fatal

  def loadPackage (path, package)
    if (digest = REXML::Document.new(File.new("#{path}/digest.xml")) rescue nil)
      digest.elements.each('//features/feature') {|e|
        begin
          Packo.load "#{Packo::Environment[:PROFILE]}/features/#{e.text}"
        rescue LoadError
        rescue Exception => e
          warn "Something went wrong while loading #{e.text} feature."
          Packo.debug e, :force => true
        end
      }
    end

    Packo.load "#{path}/#{package.name}.rbuild"
    Packo.load "#{path}/#{package.name}-#{package.version}.rbuild"
  end
end

end
