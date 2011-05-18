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
require 'packo/service/daemon'

module Packo

class Service
  def self.current
    @current
  end

  def self.define (options={}, &block)
    @current = Service.new(options, &block)
  end

  def self.start (name, options=[])
    system("/etc/init.d/#{name} start #{options.shelljoin}")
  end

  def self.started? (name)
    !`/etc/init.d/#{name} status`.strip.end_with('stopped')
  end

  attr_reader :options, :configuration

  alias config configuration
  alias conf   configuration

  def initialize (options={}, &block)
    @options = options
    @blocks  = {}

    if matches = File.realpath($0).match(%r{^/etc/init\.d/(.*)$})
      whole, file = matches.to_a

      if File.readable?(file)
        require 'yaml'

        @configuration = YAML::parse_file(file).transform
      end
    end

    @configuration ||= {}

    self.instance_exec(self, &block)

    self
  end

  def needs (what=nil)
    what ? @needs = what : @needs
  end

  def supervised?
    !!System.env[:INIT_SUPERVISED]
  end

  def method_missing (id, *args, &block)
    return super(id, *args) unless block

    @blocks[id] = block
  end

  def run (args)
    if args.length == 0
      puts @options[:help] if @options[:help]

      return
    end

    block = @blocks[command = args.shift.to_sym]

    if command == :start
      Package::Tags::Expression.parse(needs)
    else
      if !block
        CLI.fatal "#{@options[:name] || 'This service'} doesn't know how to do this"
        puts @options[:help] if @options[:help]

        return
      end
    end

    block.call(args) if block
  end
end

end


