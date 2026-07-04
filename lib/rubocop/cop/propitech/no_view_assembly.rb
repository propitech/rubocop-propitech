# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Flags data or object assembly inside a view template. A view consumes
      # values an earlier layer already produced (controller-assigned instance
      # variables, helpers, ViewComponents, route and i18n helpers, Design
      # tokens); it must not instantiate a domain, query, or presenter object,
      # run an ActiveRecord query, or build a lambda inline.
      #
      # Two kinds of instantiation are view-rendering machinery, not data
      # assembly, so they are allowed: a ViewComponent render target and a
      # +simple_form+ backing object. Any constant whose name ends in
      # +Component+ or +Form+ is therefore permitted (the latter also covers the
      # idiomatic blank form built to render a dynamic nested-row template).
      #
      # This cop is meant to run only over +app/views/**+ (scope it with
      # +Include+, as the shipped default does), reached through erb_lint's
      # +Rubocop+ linter so it lints the Ruby in ERB scriptlets. Plain +rubocop+
      # never enumerates +.erb+ files, so the cop is inert on the rest of the
      # tree.
      #
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
          # Only a lambda captured in a local is the smell (a closure the view
          # keeps to reuse). An inline callback argument, e.g. simple_form's
          # label_method or a component's page_url, is legitimate.
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
