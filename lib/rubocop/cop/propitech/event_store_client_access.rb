# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Keeps the event store client and its library's constants inside the app's DomainEvents wrapper.
      # @see https://github.com/propitech/movely/blob/main/docs/events.md Rule 5 of docs/events.md
      # @example Namespaces: [RubyEventStore, RailsEventStore], ClientAccessors: [event_store] (defaults)
      #   # bad
      #   Rails.configuration.event_store.publish(event)
      #   Rails.application.config.event_store.read.stream("orders").to_a
      #   raise RubyEventStore::EventNotFound
      #   mount RailsEventStore::Browser, at: "/event_store"
      #
      #   # good
      #   EventPublisher.new(actor: user).publish(DomainEvents::Booking::Booked, data: {booking_id: 1})
      #   DomainEvents.find(event_id)
      class EventStoreClientAccess < Base
        MSG_CONST = "Do not reference `%<name>s` outside the `DomainEvents` wrapper; publish through " \
                    "`%<publisher>s` (docs/events.md Rule 5)."
        MSG_CLIENT = "Do not reach the event store client through `%<name>s` outside the `DomainEvents` " \
                     "wrapper; publish through `%<publisher>s` (docs/events.md Rule 5)."

        # @!method rails_config?(node)
        def_node_matcher :rails_config?, <<~PATTERN
          {
            (send (const {nil? cbase} :Rails) :configuration)
            (send (send (const {nil? cbase} :Rails) :application) :config)
          }
        PATTERN

        def on_const(node)
          return unless node.namespace.nil? || node.namespace.cbase_type?
          return unless namespaces.include?(node.short_name.to_s)

          add_offense(node, message: format(MSG_CONST, name: node.short_name, publisher: publisher))
        end

        def on_send(node)
          return unless rails_config?(node.receiver)
          return unless client_accessors.include?(node.method_name.to_s.delete_suffix("="))

          range = node.receiver.source_range.join(node.loc.selector)
          add_offense(range, message: format(MSG_CLIENT, name: range.source, publisher: publisher))
        end

        private

        def namespaces
          cop_config.fetch("Namespaces", %w[RubyEventStore RailsEventStore])
        end

        def client_accessors
          cop_config.fetch("ClientAccessors", %w[event_store])
        end

        def publisher
          cop_config.fetch("Publisher", "DomainEvents::Publisher")
        end
      end
    end
  end
end
