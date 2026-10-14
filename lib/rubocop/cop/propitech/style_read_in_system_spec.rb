# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Warns about a computed-style or geometry read in a system spec: such a pin belongs in the
      # component or view spec. A read that states an accessibility requirement (a hit target, a
      # focus ring) stays, silenced by an ordinary `rubocop:disable` comment that carries the reason.
      # A method defined in the same file that interpolates a parameter into such a script string
      # (`def measure(script) = page.evaluate_script("#{script}")`) is followed: the strings given to
      # a receiverless call of it are checked like a direct script: a string argument, or a string
      # value of a keyword argument. The cop sees one file at a time and only a string at the call, so
      # it does not see a script held in a constant or a method of another file and passed by reference
      # (`page.evaluate_script(MemberCardProbe::LINK)`). The only way to have such a read checked is to
      # write the script literal, or a same-file helper call, at the call site in the spec.
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

        def_node_matcher :native_read?, <<~PATTERN
          (call (call _ :native) {:size :location})
        PATTERN

        def on_new_investigation
          super
          @script_helpers = collect_script_helpers
        end

        def on_send(node)
          if SCRIPT_METHODS.include?(node.method_name)
            check_script(node.arguments)
          elsif script_helper_call?(node)
            check_script(helper_arguments(node))
          elsif NATIVE_READS.include?(node.method_name) && native_read?(node)
            add_offense(node, message: format(MSG_NATIVE, read: "native.#{node.method_name}"))
          end
        end
        alias on_csend on_send

        private

        # Names of the methods this file defines whose body interpolates one of their own
        # parameters into a script string, such as `def measure(script) = page.evaluate_script("#{script}")`.
        def collect_script_helpers
          ast = processed_source.ast
          return [] unless ast

          ast.each_node(:def).filter_map do |definition|
            definition.method_name if script_helper?(definition)
          end
        end

        def script_helper?(definition)
          parameters = definition.arguments.argument_list.filter_map(&:name)
          definition.each_descendant(:send, :csend).any? do |call|
            SCRIPT_METHODS.include?(call.method_name) && interpolates?(call, parameters)
          end
        end

        def interpolates?(call, parameters)
          call.arguments.any? do |argument|
            argument.dstr_type? && argument.each_node(:lvar).any? do |name|
              parameters.include?(name.children.first)
            end
          end
        end

        def helper_arguments(node)
          node.arguments.flat_map { |argument| argument.hash_type? ? argument.values : [argument] }
        end

        def script_helper_call?(node)
          node.receiver.nil? && @script_helpers.include?(node.method_name)
        end

        def check_script(arguments)
          arguments.each do |argument|
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
