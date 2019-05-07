# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'internal_api/version'

Gem::Specification.new do |spec|
  spec.name          = 'internal_api'
  spec.version       = InternalApi::VERSION
  spec.authors       = ['Jack Danger']
  spec.email         = ['github@jackcanty.com']

  spec.summary       = 'Carve up your Rails monolith via internal APIs'
  spec.description   = 'Create code boundaries within your Rails monolith'
  spec.homepage      = 'https://github.com/JackDanger/ruby_internal_api'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'method_source'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end
