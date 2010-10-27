#! /usr/bin/env ruby
require 'packo'
require 'packo/modules/fetch'
require 'packo/modules/autotools'

package = Packo::Package.new('system/libraries/ncurses') {
  use Packo::Modules::Fetch
  use Packo::Modules::Autotools

  flavors {
    binary; headers; doc; minimal; debug;

    cxx { enabled!
      description = 'Enable C++ support'
    }

    unicode { enabled!
      on :configure do |conf|
        conf.set('unicode', enabled?)
      end
    }

    gpm {
      description = 'Add mouse support.'

      on :initialize do
        dependencies << 'gpm'
      end

      on :configure do |conf|
        conf.set('gpm', f.enabled?)
      end
    }

    ada {
      description = 'Add ADA support.'

      on :configure do |conf|
        conf.set('ada', enabled?) 
      end
    }
  }

  source = 'http://ftp.gnu.org/pub/gnu/ncurses/ncurses-#{VERSION}.tar.gz'
}

puts package.inspect
