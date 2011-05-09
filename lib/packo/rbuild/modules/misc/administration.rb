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

module Packo; module RBuild; module Modules; module Misc

class Administration
  def initialize (package)
    super(package)

    package.before :pack do
      next if package.admin.empty?

      package.filesystem.post.install << FFFS::File.new('administration_script', package.admin.to_s)
    end

    package.admin = Class.new(Module::Helper) {
      def initialize (package)
        super(package)

        @script = "#! /bin/sh\n"
      end

      def reset
        @script = "#! /bin/sh\n"
      end

      def empty?
        @script == "#! /bin/sh\n"
      end

      def to_s
        @script
      end

      def do
        yield self
      end

      def groupadd (name, options={})
        command = ['groupadd']
        
        if options[:force]
          command << '-f'
        end

        if options[:id]
          command << '-g' << options[:id]
        end

        if options[:system]
          command << '-r'
        end

        if options[:data]
          data.each {|key, value|
            command << '-K' << "#{key}=#{value}"
          }
        end

        if options[:password]
          command << '-p' << options[:password]
        end

        command << name

        @script << "#{command.shelljoin}\n"
      end

      def groupmod (name, options={})
        command = ['groupmod']

        if options[:id]
          command << '-g' << options[:id]
        end

        if options[:rename]
          command << '-n' << options[:rename]
        end

        if options[:unique] == false
          command << '-o'
        end

        if options[:password]
          command << '-p' << options[:password]
        end

        command << name

        @script << "#{command.shelljoin}\n"
      end

      def groupdel (name)
        command = ['groupdel']

        command << name

        @script << "#{command.shelljoin}\n"
      end

      def useradd (name, options={})
        command = ['useradd']

        if options[:base]
          command << '-b' << options[:base]
        end

        if options[:home]
          command << '-d' << options[:home]
        end

        if options[:expire]
          command << (options[:expire].strftime('%Y-%m-%d') rescue options[:expire].to_s)
        end

        if options[:inactivity]
          command << '-f' << options[:inactivity]
        end

        if options[:group]
          command << '-g' << options[:group]
        end

        if options[:groups]
          command.insert(-1, options[:groups])
        end

        if options[:skeleton]
          command << '-k' << options[:skeleton]
        end

        if options[:data]
          data.each {|key, value|
            command << '-K' << "#{key}=#{value}"
          }
        end

        if options[:log] == false
          command << '-l'
        end

        options[:create] ||= {}

        if options[:create][:home] || options[:home]
          command << '-m'
        else
          command << '-M'
        end

        if options[:create][:group] == false
          command << '-N'
        else
          command << '-U'
        end

        if options[:password]
          commad << '-p' << options[:password]
        end

        if options[:system]
          command << '-r'
        end

        if options[:shell]
          command << '-s' << options[:shell]
        end

        if options[:id]
          command << '-u' << options[:id]
        end

        command << name

        @script << "#{command.shelljoin}\n"
      end

      def usermod (name, options={})
        command = ['usermod']

        if options[:comment]
          command << '-c' << options[:comment]
        end

        if options[:home]
          command << '-d' << options[:home]
        end

        if options[:expire]
          command << (options[:expire].strftime('%Y-%m-%d') rescue options[:expire].to_s)
        end

        if options[:inactivity]
          command << '-f' << options[:inactivity]
        end

        if options[:group]
          command << '-g' << options[:group]
        end

        if options[:groups]
          groups = options[:groups].dup

          if groups.first == :+
            command << '-a'
            groups.shift
          end

          command.insert(-1, groups)
        end

        if options[:name]
          command << '-l' << options[:name]
        end

        if options[:lock]
          command << '-L'
        elsif options[:unlock]
          command << '-U'
        end

        if options[:move]
          command << '-m'
        end

        if options[:unique] == false
          command << '-o'
        end

        if options[:password]
          commad << '-p' << options[:password]
        end

        if options[:shell]
          command << '-s' << options[:shell]
        end

        if options[:id]
          command << '-u' << options[:id]
        end

        command << name

        @script << "#{command.shelljoin}\n"
      end

      def userdel (name)
        command = ['userdel']

        if options[:force]
          command << '-f'
        end

        if options[:delete]
          command << '-r'
        end

        command << name

        @script << "#{command.shelljoin}\n"
      end

      def chown (path, options={})
        command = ['chown']

        command << '-hR'
        command << "#{options[:user]}:#{options[:group]}"

        @script << "#{command.shelljoin}\n"
      end
    }.new(package)
  end

  def finalize
    package.admin = nil
  end
end

end; end; end; end
