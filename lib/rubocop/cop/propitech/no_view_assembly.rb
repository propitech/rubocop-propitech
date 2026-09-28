# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Flags data or object assembly inside a view template.
      # @example
      #   # bad
      #   <% label = SpaceLabel.new(space).to_s %>
      #   <% rows  = Taxon.kind_amenity.order(:name).to_a %>
      #   <% step  = ->(on:) { some_path(on:) } %>  # a closure captured for reuse
      #
      #   # good
      #   <%= space_label(space) %>                    # a helper
      #   <%= render Card::Component.new(row: row) %>   # a ViewComponent
      #   <%= link_to t(".prev"), some_path(on: @cursor) %>  # assigned upstream
      #   <%= f.input :x, collection: xs, label_method: ->(x) { label(x) } %>  # inline callback, fine
      class NoViewAssembly < Base
        MSG_NEW = "Do not instantiate %<const>s in a view. Move it to a helper " \
                  "or assign it in the controller; only a ViewComponent (`*::Component`) " \
                  "or a simple_form object (`*Form`) may be built in a template."

        ALLOWED_SUFFIXES = %w[Component Form].freeze
        MSG_QUERY = "Do not run a query (`%<method>s`) in a view. Load the records in " \
                    "the controller (optionally via a query object) and pass the result."
        MSG_LAMBDA = "Do not capture a lambda or proc in a view local. Use a helper, or " \
                     "call the route helper inline on objects the controller assigned. " \
                     "(An inline callback, e.g. simple_form's label_method, is fine.)"

        QUERY_METHODS = %i[where order pluck find_by find_each includes joins distinct group].freeze

        def on_send(node)
          check_instantiation(node)
          check_query(node)
        end

        def on_block(node)
          return unless node.lambda? || %i[lambda proc].include?(node.method_name)
          return unless node.parent&.lvasgn_type?

          add_offense(node, message: MSG_LAMBDA)
        end
        alias on_numblock on_block

        private

        def check_instantiation(node)
          receiver = node.receiver
          return unless node.method?(:new) && receiver&.const_type?

          const = receiver.const_name
          return if const.end_with?(*ALLOWED_SUFFIXES)

          add_offense(node.loc.selector, message: format(MSG_NEW, const: const))
        end

        def check_query(node)
          method = node.method_name
          return unless QUERY_METHODS.include?(method) && node.receiver

          add_offense(node.loc.selector, message: format(MSG_QUERY, method: method))
        end
      end
    end
  end
end
