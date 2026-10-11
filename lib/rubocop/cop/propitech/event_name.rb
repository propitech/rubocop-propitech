# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Names each domain event `<domain>.<fact>` by its place, with the fact in the past tense.
      # @see https://github.com/propitech/movely/blob/main/docs/events.md Rule 2 of docs/events.md
      # @example Namespace: DomainEvents, BaseClass: Event (defaults)
      #   # bad
      #   module DomainEvents
      #     class Booked < Event; end
      #     module Booking
      #       class Book < Event; end
      #     end
      #   end
      #
      #   # good
      #   module DomainEvents
      #     module Booking
      #       class Booked < Event; end
      #       class Withdrawn < Event; end
      #     end
      #   end
      class EventName < Base
        MSG_PLACE = "Declare `%<name>s` at `%<namespace>s::<Domain>::<Fact>`; that place is its " \
                    "`<domain>.<fact>` name (docs/events.md Rule 2)."
        MSG_TENSE = "Name the fact of `%<name>s` in the past tense (booked, not book): an event states " \
                    "what already happened (docs/events.md Rule 2)."

        # The defaults agree with movely's domain_event generator, so a name it accepts is never an offence.
        PAST_PARTICIPLES = %w[paid sent made held begun gone lost taken given shown built bought kept left spent
                              told sold found won chosen written broken frozen hidden known seen done reset drawn
                              withdrawn].freeze
        PARTICIPLE_PREFIXES = %w[re over under un mis out pre up].freeze
        NOT_PAST_TENSE = %w[need feed speed seed bleed breed weed deed heed creed greed].freeze

        def on_class(node)
          return unless node.parent_class&.const_type?

          crefs = enclosing_crefs(node)
          return unless event_base?(node.parent_class, crefs)

          check(node.identifier, nest(crefs.last || [], node.identifier))
        end

        private

        def check(identifier, path)
          if path.size != 3 || path.first != namespace
            report(identifier, MSG_PLACE, path)
          elsif !past_tense?(path.last)
            report(identifier.loc.name, MSG_TENSE, path)
          end
        end

        def report(range, message, path)
          add_offense(range, message: format(message, name: path.join("::"), namespace: namespace))
        end

        # The full path of each class or module around the node, outermost first.
        def enclosing_crefs(node)
          node.each_ancestor(:class, :module).to_a.reverse.each_with_object([]) do |scope, crefs|
            crefs << nest(crefs.last || [], scope.identifier)
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

        # A bare base class name resolves to the namespace's own only from a scope that is the namespace.
        def event_base?(superclass, crefs)
          name = superclass.const_name
          return true if name == "#{namespace}::#{base_class}"

          name == base_class && !absolute?(superclass) && crefs.include?([namespace])
        end

        def past_tense?(fact)
          word = last_word(fact)
          return false if cop_config.fetch("NotPastTense", NOT_PAST_TENSE).include?(word)

          participle?(word) || (word.end_with?("ed") && word.length > 3)
        end

        def participle?(word)
          participles = cop_config.fetch("PastParticiples", PAST_PARTICIPLES)
          ["", *cop_config.fetch("ParticiplePrefixes", PARTICIPLE_PREFIXES)].any? do |prefix|
            word.start_with?(prefix) && participles.include?(word.delete_prefix(prefix))
          end
        end

        # The last word of a constant name, split the way ActiveSupport's `underscore` splits it.
        def last_word(name)
          name.gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.split("_").last
        end

        def namespace
          cop_config.fetch("Namespace", "DomainEvents")
        end

        def base_class
          cop_config.fetch("BaseClass", "Event")
        end
      end
    end
  end
end
