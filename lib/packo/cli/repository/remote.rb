# encoding: utf-8
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

require 'packo/cli/thor'
require 'packo/models'
require 'packo/do/repository'

module Packo; module CLI; class Repository < Thor

class Remote < Thor
  include Thor::Actions

  class_option :help, type: :boolean, desc: 'Show help usage'

  desc 'add URI...', 'Add remote sets'
  map '-a' => :add
  def add (*uris)
    uris.each {|uri|
      begin
        remote = Do::Repository::Remote.add(uri)

        CLI.info "Added #{remote.name}"
      rescue Exception => e
        CLI.fatal "Failed to add #{uri}"

        Packo.debug e
      end
    }
  end

  desc 'delete NAME...', 'Delete installed remote sets'
  map '-d' => :delete, '-R' => :delete
  def delete (*names)
    names.each {|name|
      begin
        Do::Repository::Remote.delete(Models::Repository::Remote.first(name: name))
      rescue Exception => e
        CLI.fatal "Failed to delete #{uri}"

        Packo.debug e
      end
    }
  end

  desc 'update [NAME...]', 'Update installed remote sets'
  map '-u' => :update
  def update (*names)
    if names.empty?
      names = Models::Repository::Remote.all.map {|remote|
        remote.name
      }
    end

    names.each {|name|
      begin
        if Do::Repository::Remote.update(Models::Repository::Remote.first(name: name))
          CLI.info "Updated #{name}"
        else
          CLI.info "#{name} already up to date"
        end
      rescue Exception => e
        CLI.fatal "Failed to update #{name}"

        Packo.debug e
      end
    }
  end

  desc 'list [NAME]', 'List available remotes'
  def list (name=nil)
    (name ? [Models::Repository::Remote.first(name: name)] : Models::Repository::Remote.all).each {|remote|
      print remote.name.to_s.green
      print ", #{remote.description}" if remote.description
      puts ':'

      length = remote.pieces.map {|piece|      
        "#{piece.type}/#{piece.name}".length
      }.max

      remote.pieces.each {|piece|
        print '    '
        print "#{piece.type}/#{piece.name}".bold
        print ' ' * (4 + length - "#{piece.type}/#{piece.name}".length)
        puts  piece.description
      }
      
      puts ''
    }
  end
end

end; end; end
