#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free :software => you can redistribute it and/or modify
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

module Packo

class Profile
  def self.path (path)
    return unless File.directory?(path)

    Profile.new(
      :config =>   "#{path}/config",
      :modules =>  "#{path}/modules",
      :packages => "#{path}/packages"
    )
  end

  attr_reader :paths

  def initialize (paths={})
    @paths = paths

    if !@paths.is_a?(Hash)
      @paths = @paths.to_hash rescue {}
    end

    @paths.delete_if {|_, path|
      !File.file?(path) || !File.readable?(path)
    }

    @paths.dup.each {|name, path|
      @paths[name] = Path.new(path)
    }
  end

  def method_missing (id, *args)
    id = id.to_s.sub(/[=?]$/, '').to_sym

    if args.length == 0
      return @paths[id]
    else
      if respond_to? "#{id}="
        send "#{id}=", *args
      else
        @paths[id] = Path.new(args.first)
      end
    end
  end

  def apply! (environment, package=nil)
    mod = ::Module.new

    begin
      suppress_warnings {
        mod.module_eval File.read(config)
      } if File.readable?(config.to_s)
    rescue Exception => e
      Packo.debug e
    end

    if package
      if File.directory?(modules.to_s)
        Dir.glob("#{modules}/*").each {|script|
          package.instance_exec(package, File.read(script)) if File.readable?(script)
        }
      end

      if File.readable?(packages.to_s)
        file    = File.read(packages.to_s)
        checks  = {}
        configs = file.split(/^\s*!.*?$/)[1 .. -1]

        file.scan(/^\s*!\s*(.*?)\s*$/).flatten.each_with_index {|name, index|
          checks[name] = configs[index]
        }

        checks.each {|expression, config|
          whole, pkg, expr = expression.match(/^(.*?)?\s*(?:\((.*)\))?\s*(#.*)?$/).to_a.map {|p|
            p.strip if p && !p.strip.empty?
          }

          next unless Packo::Package::Dependency.parse(pkg.strip).in?(package) if pkg
          next unless Packo::Package::Tags::Expression.parse(expr.strip).evaluate(package) if expr

          begin
            suppress_warnings {
              mod.module_eval config
            }
          rescue Exception => e
            Packo.debug e
          end
        }
      end
    end

    mod.constants.each {|const|
      environment[const] = mod.const_get const
    }
  end

  def hash
    @paths.hash
  end
end

end
