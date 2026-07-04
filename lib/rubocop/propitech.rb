# frozen_string_literal: true

# RuboCop plugin entry point, lazily autoloaded so requiring this gem in an
# application never pulls RuboCop into the load path. RuboCop's plugin loader
# references the constant only when a consuming repo lists `rubocop-propitech`
# under `plugins:` in its `.rubocop.yml`.
require_relative "propitech/version"

module RuboCop # :nodoc:
  module Propitech # :nodoc:
    autoload :Plugin, "rubocop/propitech/plugin"
  end
end
