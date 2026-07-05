# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Enforces that seed data is built with FactoryBot factories and their
      # traits. A factory is the only sanctioned way to build a seed row: the
      # trait is the shared vocabulary between seeds and specs, so seed rows and
      # test rows exercise the same code and never drift.
      #
      # Two constructs are flagged inside a seed file:
      #
      # 1. A hand-rolled model create -- a constant receiver followed by
      #    +.create+ / +.create!+ (+Space.create!(...)+,
      #    +Billing::Invoice.create(...)+). +FactoryBot.create+ /
      #    +FactoryGirl.create+ are allowed; +find_or_create_by+, +create_with+,
      #    and any other method are not +.create+ and pass untouched.
      # 2. A business-logic command invocation -- a reference to a +Commands::...+
      #    class (+Commands::Spaces::Create.call(...)+). A command runs operation
      #    side-effects (validation, events, transactions) that seed data must
      #    not depend on; the row is built with the factory, not driven through
      #    the command.
      #
      # This cop is meant to run only over the seed files (scope it with
      # +Include+, as the shipped default does).
      #
      # @example
      #   # bad
      #   Space.create!(name: "Studio A")
      #   Commands::Spaces::Create.call(name: "Studio A")
      #
      #   # good
      #   FactoryBot.create(:space, :studio, name: "Studio A")
      class SeedUsesFactory < Base
        MSG_CREATE = "Do not hand-roll `%<const>s.create` in a seed. Build the row with " \
                     "`FactoryBot.create(:model, :trait)` -- add a trait if the variation " \
                     "needs a name."
        MSG_COMMAND = "Do not drive a seed row through `%<const>s`. A command runs operation " \
                      "side-effects (validation, events, transactions) a seed must not depend " \
                      "on; build the row with `FactoryBot.create(:model, :trait)` instead."

        CREATE_METHODS = %i[create create!].freeze
        ALLOWED_CREATE_RECEIVERS = %w[FactoryBot FactoryGirl].freeze

        def on_send(node)
          return unless CREATE_METHODS.include?(node.method_name)

          receiver = node.receiver
          return unless receiver&.const_type?
          return if ALLOWED_CREATE_RECEIVERS.include?(receiver.const_name)

          add_offense(node.loc.selector, message: format(MSG_CREATE, const: receiver.const_name))
        end

        def on_const(node)
          # Only the outermost const in a chain: skip the inner nodes of
          # `Commands::Spaces::Create` so the reference reports once.
          return if node.parent&.const_type?

          name = node.const_name
          return unless name && (name == "Commands" || name.start_with?("Commands::"))

          add_offense(node, message: format(MSG_COMMAND, const: name))
        end
      end
    end
  end
end
