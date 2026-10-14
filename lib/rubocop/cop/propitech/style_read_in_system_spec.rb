# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Warns about a computed-style or geometry read in a system spec: such a pin belongs in the
      # component or view spec. A read that states an accessibility requirement (a hit target, a
      # focus ring) stays, silenced by an ordinary `rubocop:disable` comment that carries the reason.
      # @example
      #   # bad
      #   page.evaluate_script("getComputedStyle(el).display")
      #   find("button").native.size
      #
      #   # good, the reason is an accessibility requirement
      #   # rubocop:disable Propitech/StyleReadInSystemSpec -- 44 px hit target
      #   page.evaluate_script("document.querySelector('button').getBoundingClientRect().height")
      #   # rubocop:enable Propitech/StyleReadInSystemSpec
      class StyleReadInSystemSpec < Base
        MSG_SCRIPT = "Do not read a computed style or a box (`%<read>s`) in a system spec: pin it in the " \
                     "component or view spec. A read for an accessibility requirement stays with a " \
                     "`rubocop:disable` comment that gives the reason."
        MSG_NATIVE = "Do not read the element's `%<read>s` in a system spec: pin it in the component or " \
                     "view spec. A read for an accessibility requirement stays with a `rubocop:disable` " \
                     "comment that gives the reason."

        SCRIPT_METHODS = %i[evaluate_script evaluate_async_script execute_script].freeze
        STYLE_READS = %w[getComputedStyle getBoundingClientRect].freeze
        NATIVE_READS = %i[size location].freeze

        RESTRICT_ON_SEND = SCRIPT_METHODS + NATIVE_READS

        def_node_matcher :native_read?, <<~PATTERN
          (call (call _ :native) {:size :location})
        PATTERN

        def on_send(node)
          if SCRIPT_METHODS.include?(node.method_name)
            check_script(node)
          elsif native_read?(node)
            add_offense(node, message: format(MSG_NATIVE, read: "native.#{node.method_name}"))
          end
        end
        alias on_csend on_send

        private

        def check_script(node)
          node.arguments.each do |argument|
            next unless argument.str_type? || argument.dstr_type?

            content = argument.each_node(:str).map(&:value).join
            read = STYLE_READS.find { |name| content.include?(name) }
            add_offense(argument, message: format(MSG_SCRIPT, read: read)) if read
          end
        end
      end
    end
  end
end
