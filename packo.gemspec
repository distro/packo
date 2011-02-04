Kernel.load 'lib/packo/version.rb'

Gem::Specification.new {|s|
    s.name         = 'packo'
    s.version      = Packo.version.to_s
    s.author       = 'meh.'
    s.email        = 'meh@paranoici.org'
    s.homepage     = 'http://github.com/distro/packo'
    s.platform     = Gem::Platform::RUBY
    s.summary      = 'The "pacco" package manager.'
    s.files        = Dir.glob('lib/**/*.rb')
    s.require_path = 'lib'
    s.executables  = Dir.glob('bin/**').map {|p| p[4, p.length]}
    s.has_rdoc     = false

    s.add_dependency('nokogiri')
    s.add_dependency('thor')
    s.add_dependency('datamapper')
    s.add_dependency('versionomy')
    s.add_dependency('fffs')
    s.add_dependency('colorb')
    s.add_dependency('ruby-lzma')
    s.add_dependency('json')
}
