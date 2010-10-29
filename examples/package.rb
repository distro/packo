#! /usr/bin/env ruby
require 'packo'
require 'packo/behaviors/gnu'

Packo::Package.new('system/libraries/ncurses') {
  behavior Packo::Behaviors::GNU

  description 'console display library'
  homepage    'http://www.gnu.org/software/ncurses/', 'http://dickey.his.com/ncurses/'
  license     'MIT'

  source 'http://ftp.gnu.org/pub/gnu/ncurses/ncurses-#{package.version}.tar.gz'

  flavors {
    binary; headers; doc; minimal; debug;

    cxx { enabled!
      description = 'Enable C++ support'

      on :configure do |conf|
        conf.with ['cxx', 'cxx-binding'], enabled?
      end
    }

    unicode { enabled!
      on :unpacked do |file|
        if !File.exists? "#{package.workdir}/ncursesw"
          FileUtils.cp_r "#{package.workdir}/ncurses-#{package.version}", "#{package.workdir}/ncursesw", :preserve => true
        end
      end

      on :compiled do |conf|
        next if !enabled?

        conf = conf.clone

        conf.enable 'widec'
        conf.set 'includedir', "#{package.distdir}/usr/include/ncursesw"

        Dir.chdir "#{package.workdir}/ncursesw"

        conf.module.do_configure(conf, false)
        conf.module.do_compile(conf, false)

        Dir.chdir "#{package.workdir}/ncurses-#{package.version}"
      end

      on :installed do |conf|
        Dir.chdir "#{package.workdir}/ncursesw"

        conf.module.do_install(nil, false)
      end
    }

    gpm {
      description = 'Add mouse support.'

      on :dependencies do |package|
        package.dependencies << 'system/libraries/gpm' if enabled?
      end

      on :configure do |conf|
        conf.with 'gpm', enabled?
      end
    }

    ada {
      description = 'Add ADA support.'

      on :configure do |conf|
        conf.with 'ada', enabled?
      end
    }
  }

  on :initialize do
    package.workdir = "#{package.directory}/work"
    package.distdir = "#{package.directory}/dist"
  end

  on :unpacked, 10 do
    Dir.chdir "#{package.workdir}/ncurses-#{package.version}"
  end

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
