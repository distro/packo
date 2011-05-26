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

module Packo; module RBuild; module Modules; module Building

class Scons < Module
  class Configuration
    attr_reader :module

    def initialize (mod=nil)
      @module = mod

      @options = {}
    end

    def clear
      @options.clear
    end

    def enable (*names)
      names.flatten.compact.each {|name|
        @options[name.to_s] = true
      }
    end

    def disable (*names)
      names.flatten.compact.each {|name|
        @options[name.to_s] = false
      }
    end

    def set (name, value)
      @options[name.to_s] = value.to_s
    end

    def get (name)
      @options[name.to_s]
    end

    def delete (*names)
      names.flatten.each {|name|
        @options.delete(name.to_s)
      }
    end

    def to_s
      result = ''

      @options.each {|name, value|
        case value
          when true;  result += "#{name.shellescape}=on "
          when false; result += "#{name.shellescape}=off "
          else;       result += "#{name.shellescape}=#{value.shellescape} "
        end
      }

      return result
    end
  end

  def initialize (package)
    super(package)

    package.avoid package.stages.owner_of(:compile)

    package.stages.add :configure, self.method(:configure), after: :fetch
    package.stages.add :compile,   self.method(:compile),   after: :configure
    package.stages.add :install,   self.method(:install),   after: :compile

    package.before :initialize do
      package.dependencies << 'development/utility/scons!'
    end

    package.scons = Class.new(Module::Helper) {
      def initialize (package)
        super(package)
      end

      def do (*args)
        package.environment.sandbox {
          Packo.sh 'scons', *args
        }
      end
    }.new(package)
  end

  def finalize
    package.stages.delete :configure, self.method(:configure)
    package.stages.delete :compile,   self.method(:compile)
    package.stages.delete :install,   self.method(:install)
  end

  def configure
    @configuration = Configuration.new(self)

    package.callbacks(:configure).do(@configuration)
  end

  def compile
    package.callbacks(:compile).do(@configuration) {
      package.scons.do @configuration.to_s.shellsplit
    }
  end

  def install
    package.callbacks(:install).do(@configuration)
  end
end

end; end; end; end
