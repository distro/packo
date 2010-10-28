#! /usr/bin/env ruby
require 'packo'
require 'packo/modules/fetch'
require 'packo/modules/autotools'

Packo::Package.new('system/libraries/ncurses') {
  use Packo::Modules::Fetch
  use Packo::Modules::Autotools

  source 'http://ftp.gnu.org/pub/gnu/ncurses/ncurses-#{version}.tar.gz'

  flavors {
    binary; headers; doc; minimal; debug;

    cxx { enabled!
      description = 'Enable C++ support'

      on :configure do |conf|
        conf.set('cxx', enabled?)
        puts conf.inspect
      end
    }

    unicode { enabled!
      on :configure do |conf|
        conf.set('unicode', enabled?)
      end
    }

    gpm {
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
}

package = Packo::Package.new('system/libraries/ncurses', '5.7')

package.build

#puts package.inspect
#puts package.dependencies.inspect
