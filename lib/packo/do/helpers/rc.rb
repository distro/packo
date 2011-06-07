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

module Packo; class Do

module RC
  Config   = YAML.parse_file('/etc/rc.conf').transform rescue {}
  Runlevel = `runlevel`.strip.match(/^.*?(\d+)$/)[1].to_i rescue 0

  module Hooks
    def self.[] (*name)
      Class.new {
        def initialize (*name)
          @name = name
        end

        def run (*args)
          Dir["/sbin/rc.d/hooks/#{@name.join('/')}/*"].each {|hook|
            sh! hook, *args
          }
        end
      }.new(name)
    end
  end

  def timezone?
    Config['general']['timezone'] && File.readable?("/usr/share/zoneinfo/#{Config['general']['timezone']}")
  end

  def random_seed?
    File.readable('/var/lib/misc/random-seed')
  end

  def crypttab?
    File.readable?('/etc/crypttab') && File.read('/etc/crypttab').lines.any? {|line|
      !line.sub(/#.*$/, '').strip.empty?
    }
  end

  def raid?
    Config['system']['devices']['raid'] rescue nil
  end

  def btrfs?
    Config['system']['devices']['btrfs'] rescue nil
  end

  def lvm?
    (Config['system']['devices']['lvm'] rescue nil) && File.executable?('/sbin/lvm') && File.directory('/sys/block')
  end
    
  def lvm_start
    return unless lvm?

    sh! 'modprobe -q dm-mod'

    CLI.message 'Activating LVM2 groups...' do
      sh! 'vgchange --sysinit -a y'
    end
  end

  def reboot
    CLI.echo 'Automatic reboot in progress...'

    sh! %{
      umount -a
      mount -n -o remount,ro /
      reboot -f
    }

    exit 0
  end

  def timezone!
    "/usr/share/zoneinfo/#{Config['general']['timezone']}"
  end

  def random_seed!
    '/var/lib/misc/random-seed'
  end
end

end; end
