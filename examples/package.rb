#! /usr/bin/env ruby
require 'packo'

Packo::Package.new('system/libraries/ncurses') {
  use Packo::Modules::Fetch
  use Packo::Modules::Unpack
  use Packo::Modules::Patch
  use Packo::Modules::Autotools

  description 'console display library'
  homepage    'http://www.gnu.org/software/ncurses/', 'http://dickey.his.com/ncurses/'
  license     'MIT'

  source 'http://ftp.gnu.org/pub/gnu/ncurses/ncurses-#{version}.tar.gz'

  flavors {
    binary; headers; doc; minimal; debug;

    cxx { enabled!
      description = 'Enable C++ support'

      on :configure do |conf|
        conf.with(['cxx', 'cxx-binding'], enabled?)
      end
    }

    unicode { enabled!
      on :configure do |conf|
        conf.able('unicode', enabled?)
      end
    }

    gpm {
      description = 'Add mouse support.'

      on :dependencies do |package|
        package.dependencies << 'system/libraries/gpm' if enabled?
      end

      on :configure do |conf|
        conf.with('gpm', enabled?)
      end
    }

    ada {
      description = 'Add ADA support.'

      on :configure do |conf|
        conf.with('ada', enabled?) 
      end
    }
  }

  on :configure do |conf|
    conf.with ['shared', 'rcs-ids']
    conf.with 'manpage-format', 'normal'
    conf.without 'hashed-db'

    conf.enable ['symlinks', 'const', 'colorfgbg', 'echo']

    # ABI compatibility
    conf.with 'chtype', 'long'
    conf.with 'mmask-t', 'long'
    conf.disable ['ext-colors', 'ext-mouse']
    conf.without ['pthread', 'reentrant']
  end
}

package = Packo::Package.new('system/libraries/ncurses', '5.7') {
  arch '~x86', '~amd64'
}

package.build

puts package.inspect
