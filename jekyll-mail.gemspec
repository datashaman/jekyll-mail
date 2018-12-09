Gem::Specification.new do |s|
    s.name = 'jekyll-mail'
    s.version = '0.1.0'
    s.authors = ['Marlin Forbes']
    s.email = 'marlinf@datashaman.com'
    s.summary = 'Import incoming mail to your Jekyll site.'
    s.homepage = 'https://github.com/datashaman/jekyll-mail'
    s.license = 'MIT'
    s.files = [
        'lib/jekyll-mail.rb',
    ]
    s.executables = [
        'jekyll-mail',
    ]
    s.require_paths = ['lib']

    s.add_dependency 'mail', '~> 0'
    s.add_dependency 'ruby-oembed', '~> 0'

    s.add_development_dependency 'bundler', '~> 0'
    s.add_development_dependency 'jekyll', '~> 0'
    s.add_development_dependency 'rake', '~> 0'
    s.add_development_dependency 'minitest', '~> 0'
    s.add_development_dependency 'minitest-reporters', '~> 0'
    s.add_development_dependency 'rubocop-jekyll', '~> 0.4.0'
end
