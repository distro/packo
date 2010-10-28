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

      on :configure do |conf|
        conf.set('cxx', enabled?)
      end
    }

    unicode { enabled!
      on :configure do |conf|
        conf.set('unicode', enabled?)
      end
    }

    gpm { enabled!
      description = 'Add mouse support.'

      on :dependencies do |package|
        package.dependencies << 'system/libraries/gpm' if enabled?
      end

      on :configure do |conf|
        conf.set('gpm', enabled?)
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

package.build

puts package.inspect
puts package.dependencies.inspect
