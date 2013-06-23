# -*- encoding: utf-8 -*-
require File.expand_path('../lib/plerrex/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["snukky"]
  gem.email         = ["snk987@gmail.com"]
  gem.description   = %q{Automatic extraction of various kinds of errors such 
                      as spelling, typographical, grammatical, syntactic, 
                      semantic, and stylistic ones from text edition history.
                      Works with texts composed in Polish language.}
  gem.summary       = %q{Automatic extraction of polish language errors from 
                      text edition history.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "plerrex"
  gem.require_paths = ["lib"]
  gem.bindir        = "bin"
  gem.version       = Plerrex::VERSION

  gem.add_runtime_dependency 'rake'
  gem.add_runtime_dependency 'diff-lcs'
  gem.add_runtime_dependency 'srx-polish'
  gem.add_runtime_dependency 'damerau-levenshtein'
  gem.add_runtime_dependency 'polish_chars'
  gem.add_runtime_dependency 'morfologik'
  gem.add_runtime_dependency 'hunspell-ffi'
  gem.add_runtime_dependency 'colorize'

  gem.add_development_dependency 'rspec', '>= 2.0.0'
  gem.add_development_dependency 'rspec-expectations', '>= 2.0.0'
  gem.add_development_dependency 'awesome_print'
end
