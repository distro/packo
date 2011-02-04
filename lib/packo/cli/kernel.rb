# encoding: utf-8
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

require 'open-uri'
require 'yaml'

module Packo; module CLI

class Kernel < Thor
  include Thor::Actions

  class_option :source, :type => :string, :desc => 'Select config file to read from', :default => 'https://github.com/distro/data/raw/master/kernels.yaml'

  def initialize (*args)
    super(*args)

    unless args[2][:current_task][:description] == 'A dynamically-generated task' || args[2][:current_task][:name] == 'help'
      @kernels = YAML.parse(open(options[:source]).read).transform
    end
  end

  desc 'list', 'List available kernels'
  map '-l' => :list
  def list
    @kernels.each {|kernel|
      puts  "#{'Kernel:'.green}      #{kernel['name']}"
      puts  "#{'Description:'.green} #{kernel['description']}"
      print "#{'Versions:'.green}    "

      prefix = kernel['prefix'] || kernel['name'].strip.downcase

      (kernel['versions'] || []).each {|kernel|
        print "#{prefix.white.bold}-#{kernel['version'].to_s.red}"
        print " -> #{prefix.white.bold}-#{kernel['alias'].to_s.red}" if kernel['alias']

        if kernel['patch']
          tmp = Packo::RBuild::Dependency.parse(kernel['patch'])

          print " patch of #{tmp.validity.to_s.magenta}#{tmp.name.white.bold}-#{tmp.version.to_s.red}"
        end

        print "\n             "
      }

      print "\n"
    }
  end

  desc 'fetch KERNEL [OPTIONS]', 'Fetch a kernel'
  map '-f' => :fetch
  method_option :output, :type => :string, :aliases => '-o', :desc => 'Output to the given directory'
  def fetch (kernel)
    kernel = Packo::RBuild::Dependency.parse(kernel)
  end
end

end; end
