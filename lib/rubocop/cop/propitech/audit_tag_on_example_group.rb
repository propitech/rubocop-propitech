# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Keeps an audit tag on the example it audits, never on a whole group.
      # @example Tags: [audit_on_pr]
      #   # bad
      #   RSpec.describe "Members", :audit_on_pr do
      #     it "invites a teacher" do; end
      #   end
      #
      #   # good
      #   RSpec.describe "Members" do
      #     it "invites a teacher", :audit_on_pr do; end
      #   end
      class AuditTagOnExampleGroup < Base
        MSG = "Put `:%<tag>s` on the example it audits, not on the group: a tag on a group audits every " \
              "example inside it."

        GROUP_METHODS = %i[describe context feature].freeze

        DEFAULTS = {
          "Tags" => []
        }.freeze

        RESTRICT_ON_SEND = GROUP_METHODS

        def_node_matcher :group_call?, <<~PATTERN
          (send {nil? (const {nil? cbase} :RSpec)} {:describe :context :feature} ...)
        PATTERN

        def on_send(node)
          return unless group_call?(node)

          node.arguments.each do |argument|
            tag = tag_name(argument)
            add_offense(argument, message: format(MSG, tag: tag)) if tag
          end
        end

        private

        # A bare symbol, or the key of a `tag: true` pair in a trailing options hash.
        def tag_name(argument)
          symbol = argument.hash_type? ? tag_key(argument) : argument
          symbol.value.to_s if symbol&.sym_type? && tags.include?(symbol.value.to_s)
        end

        def tag_key(hash)
          hash.keys.find { |key| key.sym_type? && tags.include?(key.value.to_s) }
        end

        def tags
          Array(cop_config.fetch("Tags", DEFAULTS.fetch("Tags"))).map { |tag| tag.to_s.delete_prefix(":") }
        end
      end
    end
  end
end
