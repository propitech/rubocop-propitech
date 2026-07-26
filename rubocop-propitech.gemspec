# frozen_string_literal: true

require_relative "lib/rubocop/propitech/version"

Gem::Specification.new do |spec|
  spec.name = "rubocop-propitech"
  spec.version = RuboCop::Propitech::VERSION
  spec.authors = ["Hallelujah"]
  spec.email = ["hery@rails-royce.org"]

  spec.summary = "Cross-cutting RuboCop cops for Propitech Rails apps."
  spec.description = "A RuboCop plugin shipping Propitech's shared, cross-cutting " \
                     "Rails cops, starting with Propitech/NoViewAssembly (keep data " \
                     "and object assembly out of view templates)."
  spec.homepage = "https://github.com/propitech/rubocop-propitech"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.4"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/propitech/rubocop-propitech"
  spec.metadata["changelog_uri"] = "https://github.com/propitech/rubocop-propitech/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["default_lint_roller_plugin"] = "RuboCop::Propitech::Plugin"

  spec.files =
    begin
      gemspec = File.basename(__FILE__)
      IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
        ls.readlines("\x0", chomp: true).reject do |f|
          (f == gemspec) ||
            f.start_with?(*%w[Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
        end
      end
    rescue StandardError
      []
    end

  spec.require_paths = ["lib"]

  spec.add_dependency "lint_roller", "~> 1.1"
  spec.add_dependency "rubocop", ">= 1.72"
end
