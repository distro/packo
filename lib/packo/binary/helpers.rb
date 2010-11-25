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
require 'packo/rbuild'

module Packo; module Binary

module Helpers
  def colorize (text, fg, bg=nil, attr=nil)
    return text if Environment[:NO_COLORS]

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
    options = {
      :before => 'module ::Packo::RBuild;',
      :after  => ';end'
    }

    if File.exists?("#{path}/digest.xml") && (digest = Nokogiri::XML.parse(File.read("#{path}/digest.xml")))
      features = digest.xpath("//build[@version = '#{package.version}'][@slot = '#{package.slot}']/features").first

      ap features
      
      features.text.split(' ').each {|feature|
        begin
          Packo.load "#{Environment[:PROFILE]}/features/#{feature}", options
        rescue LoadError
        rescue Exception => e
          warn "Something went wrong while loading #{feature} feature."
          Packo.debug e, :force => true
        end
      } if features
    end

    Packo.load "#{path}/#{package.name}.rbuild", options
    Packo.load "#{path}/#{package.name}-#{package.version}.rbuild", options
  end
end

end; end
