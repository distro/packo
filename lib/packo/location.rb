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

require 'nokogiri'
require 'ostruct'

module Packo

class Location < OpenStruct
  def self.[] (data={})
    if data.is_a?(Hash)
      Location.new(data)
    elsif data.is_a?(Nokogiri::XML::Element)
      Location.from_dom(data)
    else
      Location.parse(data.to_s)
    end
  end

  def self.parse (text)
    return text if text.is_a?(Location)

    if (uri = URI.parse(text) rescue nil)
      location = Location.new

      if uri.scheme.nil? || uri.scheme == 'file'
        location.type = :file
        location.path = uri.path
      elsif ['http', 'https', 'ftp'].member?(uri.scheme)
        location.type    = :url
        location.address = uri.to_s
      elsif uri.scheme == 'git'
        location.type       = :git
        location.repository = uri.to_s
      end

      location
    else
      data = {}

      parts = text.split(/\s*(?<!\\);\s*/)

      if parts.first.split(/\s*=\s*/, 2).length == 1
        data[:type] = parts.shift
      end
      
      parts.each {|part|
        name, value = part.split(/\s*=\s*/, 2)

        next unless value

        data[name.to_sym] = value.gsub('\;', ';')
      }

      Location.new(data)
    end
  end

  def self.from_dom (dom)
    data = {}

    data[:type] = dom['type']

    dom.xpath('./*').each {|e|
      data[e.name] = e.text
    }

    Location.new(data)
  end

  attr_reader :type

  def initialize (data={})
    self.type = data.delete(:type)

    super(data)
  end

  def type= (value)
    @type = value.to_sym if value
  end

  def [] (name)
    self.__send__(name)
  end

  def []= (name, value)
    self.__send__ "#{name}=", value
  end

  def to_s
    result = ''

    result << "#{@type}; " if @type

    result << self.to_hash.map {|(name, value)|
      "#{name}=#{value.to_s.gsub(';', '\;')}"
    }.join('; ')

    result
  end
end

end
