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

require 'packo/utils'
require 'packo/extensions'

module Packo
  def self.debug (argument, options={})
    return if !Packo.const_defined?(:System) || (!System.env[:DEBUG] && !options[:force])

    return if System.env[:DEBUG].to_i < (options[:level] || 1) && !options[:force]

    output = "[#{Time.new}] From: #{caller[0, options[:deep] || 1].join("\n")}\n"

    if argument.is_a?(Exception)
      output << "#{argument.class}: #{argument.message}\n"
      output << argument.backtrace.collect {|stack|
        stack
      }.join("\n")
      output << "\n\n"
    elsif argument.is_a?(String)
      output << "#{argument}\n"
    else
      output << "#{argument.inspect}\n"
    end

    if options[:separator]
      output << options[:separator]
    end

    $stderr.puts output
  end
end

require 'packo/version'
require 'packo/system'
require 'packo/do'
require 'packo/location'
require 'packo/repository'
require 'packo/package'
require 'packo/requirements'
require 'packo/distfile'
require 'packo/transform'
