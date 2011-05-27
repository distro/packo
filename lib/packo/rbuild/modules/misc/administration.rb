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

module Packo; module RBuild; module Modules; module Misc

class Administration
  def initialize (package)
    super(package)

    package.before :pack do
      next if package.admin.empty?

      package.filesystem.post.install << FFFS::File.new('administration_script', package.admin.install)
      package.filesystem.post.uninstall << FFFS::File.new('administration_script', package.admin.uninstall)
    end

    package.admin = Class.new(Module::Helper) {
      def initialize (package)
        super(package)

        @raw = "#! /bin/sh\n"

        @source = {
          :install =>   @raw.dup,
          :uninstall => @raw.dup
        }

        @into = :install
      end

      def reset
        @source[:install].replace(@raw)
        @source[:uninstall].replace(@raw)
      end

      def empty?
        install == @raw && uninstall == @raw
      end

      def install
        @source[:install]
      end

      def uninstall
        @source[:uninstall]
      end

      def into?
        @into
      end

      def into (what)
        tmp, @into = @into, what

        yield

        @into = tmp
      end

      def do (&block)
        self.instance_exec(self, &block)
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

        @source[@into] << "#{command.shelljoin}\n"

        if into? == :install
          into :uninstall do
            groupdel name
          end
        end
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

        @source[@into] << "#{command.shelljoin}\n"
      end

      def groupdel (name)
        command = ['groupdel']

        command << name

        @source[@into] << "#{command.shelljoin}\n"
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

        @source[@into] << "#{command.shelljoin}\n"

        if into? == :install
          into :uninstall do
            userdel name
          end
        end
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

        @source[@into] << "#{command.shelljoin}\n"
      end

      def userdel (name, options={})
        command = ['userdel']

        if options[:force]
          command << '-f'
        end

        if options[:delete]
          command << '-r'
        end

        command << name

        @source[@into] << "#{command.shelljoin}\n"
      end

      def chown (path, options={})
        command = ['chown']

        command << '-hR'
        command << "#{options[:user]}:#{options[:group]}"
        command << path

        @source[@into] << "#{command.shelljoin}\n"

        if into? == :install
          into :uninstall do
            chown path, :user => 'nobody', :group => 'nobody'
          end
        end
      end
    }.new(package)
  end

  def finalize
    package.admin = nil
  end
end

end; end; end; end
