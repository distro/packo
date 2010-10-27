#! /usr/bin/env ruby
require 'packo'
require 'packo/modules/autotools'

puts Packo::Package.new('system/libraries/ncurses') {|p|
  p.use Packo::Modules::Autotools

  p.flavors {
    binary; headers; doc; minimal; debug;

    cxx {|f|
      f.enabled!

      f.description = 'Enable C++ support'
    }

    unicode {|f|
      f.enabled!

      f.on(:configure) {|c|
        c.set('unicode', f.enabled?)
      }
    }

    gpm {|f|
      f.description = 'Add mouse support.'

      f.on(:initialize) {
        f.dependencies << 'gpm'
      }

      f.on(:configure) {|c|
        c.set('gpm', f.enabled?)
      }
    }

    ada {|f|
      f.description = 'Add ADA support.'

      f.on(:configure) {|c|
        c.set('ada', f.enabled?) 
      }
    }
  }

  p.source = 'http://ftp.gnu.org/pub/gnu/ncurses/ncurses-#{VERSION}.tar.gz'
}.inspect
