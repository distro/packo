Gem::Specification.new {|s|
    s.name         = 'packo'
    s.version      = '0.0.1'
    s.author       = 'meh.'
    s.email        = 'meh@paranoici.org'
    s.homepage     = 'http://github.com/meh/packo'
    s.platform     = Gem::Platform::RUBY
    s.summary      = 'The "pacco" package manager.'
    s.files        = Dir.glob('lib/**/*.rb')
    s.require_path = 'lib'
    s.executables  = ['packo']
    s.has_rdoc     = true

    s.add_dependency('optitron')
    s.add_dependency('sqlite3')
}
