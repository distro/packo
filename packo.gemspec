Kernel.load 'lib/packo/version.rb'

Gem::Specification.new {|s|
    s.name         = 'packo'
    s.version      = Packo.version.to_s
    s.author       = 'meh.'
    s.email        = 'meh@paranoici.org'
    s.homepage     = 'http://github.com/distro/packo'
    s.platform     = Gem::Platform::RUBY
    s.summary      = 'The "pacco" package manager.'
    s.description  = 'A really flexible package manager, inspired by portage and pacman.'
    s.files        = Dir.glob('lib/**/*.rb')
    s.require_path = 'lib'
    s.executables  = Dir.glob('bin/**').map {|p| p[4 .. -1]}

    s.add_dependency('thor')
    s.add_dependency('colorb')

    s.add_dependency('versionub', '>= 0.0.6')
    s.add_dependency('fffs', '>= 0.0.12')
    s.add_dependency('memoized')
    s.add_dependency('sysctl')
    s.add_dependency('ffi')
    s.add_dependency('boolean-expression')

    s.add_dependency('datamapper')
    s.add_dependency('dm-transactions')
    s.add_dependency('dm-timestamps')
    s.add_dependency('dm-types')
    s.add_dependency('dm-constraints')
}
