# frozen_string_literal: true

require "pathname"
require "lint_roller"

require_relative "version"
require_relative "../cop/propitech/comment_budget"
require_relative "../cop/propitech/no_view_assembly"

module RuboCop
  module Propitech
    # LintRoller plugin registering Propitech's cross-cutting Rails cops.
    class Plugin < LintRoller::Plugin
      def about
        @about ||= LintRoller::About.new(
          name: "rubocop-propitech",
          version: VERSION,
          homepage: "https://github.com/propitech/rubocop-propitech",
          description: "Cross-cutting RuboCop cops for Propitech Rails apps."
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join("../../../config/default.yml")
        )
      end
    end
  end
end
