# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Keeps each event subscriber in its reacting domain, running only that domain's commands.
      # @see https://github.com/propitech/movely/blob/main/docs/events.md Rules 3 and 4 of docs/events.md
      # @example BaseClass: DomainEvents::Subscriber, Directory: app/jobs (defaults)
      #   # bad, in app/jobs/authorization_disconnect_subscriber.rb
      #   class AuthorizationDisconnectSubscriber < DomainEvents::Subscriber; end
      #
      #   # bad, in app/jobs/plans/broadcast_catalogue_subscriber.rb
      #   module Plans
      #     class BroadcastCatalogueSubscriber < DomainEvents::Subscriber
      #       def handle(event)
      #         Commands::Invoices::Create.call(school: event.data.fetch(:school_id))
      #         DomainEvents::Publisher.new.publish(DomainEvents::Plan::Redrawn, data: {})
      #       end
      #     end
      #   end
      #
      #   # good, in app/jobs/plans/broadcast_catalogue_subscriber.rb
      #   module Plans
      #     class BroadcastCatalogueSubscriber < DomainEvents::Subscriber
      #       def handle(event)
      #         Commands::Plans::RedrawCatalogue.call(run_id: event.data.fetch(:run_id))
      #       end
      #     end
      #   end
      class SubscriberShape < Base
        MSG_PLACE = "Declare subscriber `%<name>s` as `<Domain>::<Reaction>%<suffix>s` in " \
                    "`%<directory>s/<domain>/<reaction>_%<file_suffix>s.rb`: a subscriber belongs to the " \
                    "reacting domain (docs/events.md Rule 3)."
        MSG_BASE = "Make `%<name>s` inherit `%<base>s`: a class named and placed as a subscriber is one " \
                   "(docs/events.md Rule 3)."
        MSG_CHAIN = "Do not publish an event from subscriber `%<name>s`: chain depth is one, so a second hop " \
                    "is a saga planned in its own ticket (docs/events.md Rule 4)."
        MSG_FOREIGN = "Do not call `%<command>s` from subscriber `%<name>s` in `%<domain>s`: let the " \
                      "%<command_domain>s domain subscribe to the event itself, or plan the coordination as " \
                      "a saga (docs/events.md Rules 3 and 4)."

        DEFAULTS = {
          "BaseClass" => "DomainEvents::Subscriber",
          "Directory" => "app/jobs",
          "NameSuffix" => "Subscriber",
          "CommandsNamespace" => "Commands",
          "EventNamespace" => "DomainEvents",
          "Publisher" => "DomainEvents::Publisher",
          "PublishMethods" => %w[publish]
        }.freeze

        def on_class(node)
          path = nest(enclosing_path(node), node.identifier)
          if subscriber_base?(node.parent_class)
            check_place(node, path)
            check_body(node, path)
          elsif in_directory? && path.last.end_with?(option("NameSuffix"))
            report(node.parent_class || node.identifier, MSG_BASE, path, base: option("BaseClass"))
          end
        end

        private

        def check_place(node, path)
          suffix = option("NameSuffix")
          return if path.size == 2 && path.last.end_with?(suffix) && placed_at?(path)

          report(node.identifier, MSG_PLACE, path, suffix: suffix, directory: option("Directory"),
                                                   file_suffix: underscore(suffix))
        end

        def check_body(node, path)
          node.body&.each_node(:send, :csend, :const) do |child|
            if child.const_type?
              check_command(child, path)
            elsif publish?(child)
              report(child, MSG_CHAIN, path)
            end
          end
        end

        # A subscriber's domain is its top-level module, and its commands sit under Commands::<Domain>.
        def check_command(const, path)
          return if path.size < 2 || const.parent&.const_type?

          namespace, command_domain = const.const_name.split("::")
          return unless namespace == option("CommandsNamespace") && command_domain
          return if command_domain == path.first

          report(const, MSG_FOREIGN, path, command: const.const_name, domain: path.first,
                                           command_domain: command_domain)
        end

        def report(range, message, path, **values)
          add_offense(range, message: format(message, name: path.join("::"), **values))
        end

        def publish?(node)
          return false unless option("PublishMethods").include?(node.method_name.to_s)

          event_class?(node.first_argument) || publisher_receiver?(node.receiver)
        end

        def event_class?(node)
          node&.const_type? && node.const_name.start_with?("#{option("EventNamespace")}::")
        end

        # Matches the publisher and a per-domain subclass of it, such as Bookings::EventPublisher.
        def publisher_receiver?(node)
          publisher = option("Publisher").split("::").last
          node&.each_node(:const)&.any? { |const| const.short_name.to_s.end_with?(publisher) } || false
        end

        def placed_at?(path)
          file = processed_source.path
          return true unless file

          expected = File.join("", option("Directory"), *path.map { |segment| underscore(segment) })
          File.expand_path(file).end_with?("#{expected}.rb")
        end

        def in_directory?
          file = processed_source.path
          file && File.expand_path(file).include?(File.join("", option("Directory"), ""))
        end

        def subscriber_base?(superclass)
          superclass&.const_type? && superclass.const_name == option("BaseClass")
        end

        def enclosing_path(node)
          node.each_ancestor(:class, :module).to_a.reverse.reduce([]) do |path, scope|
            nest(path, scope.identifier)
          end
        end

        def nest(outer, const)
          segments = const.const_name.split("::")
          absolute?(const) ? segments : outer + segments
        end

        def absolute?(const)
          const = const.namespace while const.namespace&.const_type?
          const.namespace&.cbase_type? || false
        end

        # Splits a constant name the way ActiveSupport's `underscore` does.
        def underscore(name)
          name.gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
        end

        def option(key)
          cop_config.fetch(key, DEFAULTS.fetch(key))
        end
      end
    end
  end
end
