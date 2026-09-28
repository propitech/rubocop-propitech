# frozen_string_literal: true

require_relative "propitech/version"

module RuboCop # :nodoc:
  module Propitech # :nodoc:
    # RuboCop's plugin loader references this once a repo lists rubocop-propitech under plugins.
    autoload :Plugin, "rubocop/propitech/plugin"
  end
end
