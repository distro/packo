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
    s.executables  = ['packo', 'packo-files', 'packo-repository', 'packo-build', 'packo-select', 'packo-env']
    s.has_rdoc     = false

    s.add_dependency('nokogiri')
    s.add_dependency('optitron')
    s.add_dependency('datamapper')
    s.add_dependency('versionomy')
    s.add_dependency('fffs')
    s.add_dependency('colorb')
}
