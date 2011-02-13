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

module Packo

class Profile
  def self.path (path)
    return unless File.directory?(path)

    Profile.new(
      :config   => "#{path}/config",
      :tags     => "#{path}/tags",
      :packages => "#{path}/packages",
      :modules  => "#{path}/modules",
      :mask     => "#{path}/mask",
      :unmask   => "#{path}/unmask",
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
  end

  def method_missing (id, *args)
    id = id.to_s.sub(/[=?]$/, '').to_sym

    if args.length == 0
      return @paths[id]
    else
      if respond_to? "#{id}="
        send "#{id}=", *args
      else
        @paths[id] = (args.length > 1) ? args : args.first
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

      if File.readable?(tags.to_s)
        file   = File.read(tags)
        tags   = {}
        values = file.split(/^\s*\[.*?\]\s*$/); values.shift

        file.scan(/^\s*\[(.*?)\]\s*$/).flatten.each_with_index {|name, index|
          tags[name] = values[index]
        }

        tags.each {|expr, value|
          next unless Packo::Package::Tags::Expression.parse(expr).evaluate(package) rescue false

          begin
            suppress_warnings {
              mod.module_eval value
            }
          rescue Exception => e
            Packo.debug e
          end
        }
      end

      if File.readable?(packages.to_s)
        file     = File.read(packages)
        packages = {}
        values   = file.split(/^\s*\[.*?\]\s*$/); values.shift

        file.scan(/^\s*\[(.*?)\]\s*$/).flatten.each_with_index {|name, index|
          packages[name] = values[index]
        }

        packages.each {|name, value|
          next unless Packo::Package::Dependency.parse(name).in?(package) rescue false

          begin
            suppress_warnings {
              mod.module_eval value
            }
          rescue Exception => e
            Packo.debug e
          end
        }
      end

      if File.readable?(mask.to_s)
        File.read(mask).lines.each {|line|
          line.strip!

          if line.start_with?('[') && line.end_with?(']')
            if Packo::Package::Tags::Expression.parse(line[1, line.length - 2]).evaluate(package)
              package.mask!
            end
          else
            if Packo::Package::Dependency.parse(line).in?(package)
              package.mask!
            end
          end
        }
      end

      if File.readable?(unmask.to_s)
        File.read(unmask).lines.each {|line|
          line.strip!

          if line.start_with?('[') && line.end_with?(']')
            if Packo::Package::Tags::Expression.parse(line[1, line.length - 2]).evaluate(package)
              package.unmask!
            end
          else
            if Packo::Package::Dependency.parse(line).in?(package)
              package.unmask!
            end
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
