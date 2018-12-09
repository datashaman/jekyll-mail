# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "jekyll-mail"
  s.version = "0.1.0"
  s.authors = ["Marlin Forbes"]
  s.email = "marlinf@datashaman.com"
  s.summary = "Import incoming mail to your Jekyll site."
  s.homepage = "https://github.com/datashaman/jekyll-mail"
  s.license = "MIT"
  s.files = [
    "lib/jekyll-mail.rb",
  ]
  s.executables = [
    "jekyll-mail",
  ]
  s.require_paths = ["lib"]

  s.add_runtime_dependency "mail", "~> 2.5", ">= 2.5.5"
  s.add_runtime_dependency "ruby-oembed", "~> 0.10"

  s.add_development_dependency "jekyll", "~> 3.6", ">= 3.6.3"
  s.add_development_dependency "minitest", "~> 5.11"
  s.add_development_dependency "minitest-filecontent", "~> 0.1"
  s.add_development_dependency "minitest-reporters", "~> 1.3"
  s.add_development_dependency "rake", "~> 12.3"
  s.add_development_dependency "rubocop-jekyll", "~> 0.4.0"
  s.add_development_dependency "simplecov", "~> 0.16"
  s.add_development_dependency "timecop", "~> 0.9"
end
