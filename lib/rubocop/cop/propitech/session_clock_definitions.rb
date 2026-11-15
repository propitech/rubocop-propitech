# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Finds the definition behind a name in a factory call for `SessionAtClockRelativeTime`: a `let` of the
      # same file, or a local variable assigned earlier in the same block. The host cop supplies
      # `processed_source`, `duration_read?`, `clock_read?` and `open_day_helper_used?`.
      module SessionClockDefinitions
        LET_METHODS = %i[let let!].freeze

        private

        # Each name in the value mapped to the definition of the `let` or local variable it names, one level
        # deep. The checks read a name as its definition, so `today + 2` with `today = Date.current` is one
        # expression.
        def definitions_for(value, node)
          names = value.each_node(:lvar, :send).to_a
          names.to_h { |name| [name, definition_of(name, node)] }.compact
        end

        def definition_of(name, node)
          if name.lvar_type?
            local_value(name.children.first, node)
          elsif name.receiver.nil? && name.arguments.empty?
            let_value(name.method_name, node)
          end
        end

        def expand(node)
          (@definitions || {}).fetch(node, node)
        end

        # Every call in the expression and in the definition of each name it holds.
        def calls_of(expression)
          names = expression.each_node(:lvar, :send).filter_map { |name| (@definitions || {})[name] }
          [expression, *names].flat_map { |part| part.each_node(:send, :csend).to_a }
        end

        # Only a local the call can see: one assigned directly in an enclosing block, never one a parameter
        # shadows before any assignment in that scope, and never one outside the enclosing `def`.
        def local_value(name, node)
          scopes(node).each do |scope|
            assignment = last_assignment(scope, name, node)
            return assignment.children.last if assignment
            return nil if parameter?(scope, name) || scope.def_type? || scope.defs_type?
          end
          nil
        end

        def parameter?(scope, name)
          return false unless scope.block_type? || scope.def_type? || scope.defs_type?

          scope.arguments.each_descendant.any? { |arg| arg.type.to_s.end_with?("arg") && arg.children.first == name }
        end

        def last_assignment(scope, name, node)
          visible = scope.each_descendant(:lvasgn).select { |asgn| visible_assignment?(asgn, name, scope, node) }
          visible.max_by { |asgn| asgn.source_range.begin_pos }
        end

        def visible_assignment?(assignment, name, scope, node)
          assignment.children.first == name && assignment.children[1] &&
            assignment.source_range.end_pos <= node.source_range.begin_pos && owning_scope(assignment).equal?(scope)
        end

        def owning_scope(node)
          node.each_ancestor(:block, :numblock, :def, :defs).first || processed_source.ast
        end

        def let_value(name, node)
          scopes(node).lazy.filter_map do |scope|
            statements_of(scope).find { |statement| let_named?(statement, name) }&.body
          end.first
        end

        def statements_of(scope)
          body = scope.block_type? ? scope.body : scope
          body&.begin_type? ? body.children : [body].compact
        end

        def let_named?(statement, name)
          return false unless statement.respond_to?(:block_type?) && statement.block_type?

          call = statement.send_node
          call.receiver.nil? && LET_METHODS.include?(call.method_name) &&
            call.first_argument&.sym_type? && call.first_argument.value == name
        end

        # Enclosing blocks and defs from the innermost out, then the file.
        def scopes(node)
          [*node.each_ancestor(:block, :numblock, :def, :defs), processed_source.ast].compact
        end

        def bare_now?(call)
          call.method?(:now) && call.receiver.nil? && call.arguments.empty?
        end

        # True where the file defines `now` from the clock: `let(:now) { Time.current }` or
        # `def now = Time.current`. A `now` built from an open-day helper or a fixed date is not the clock.
        # The `let(:now)` or `def now` the call resolves to decides, by the nearest-group rule of every other
        # `let`; the whole file decides only where no enclosing group defines it.
        def now_from_clock?(node)
          definition = scopes(node).lazy.filter_map { |scope| now_definition_in(scope) }.first
          return clock_body?(definition.body) if definition

          @now_from_clock = file_defines_now_from_clock? if @now_from_clock.nil?
          @now_from_clock
        end

        def now_definition_in(scope)
          statements_of(scope).find { |statement| let_named?(statement, :now) || now_def?(statement) }
        end

        def now_def?(statement)
          statement.respond_to?(:def_type?) && statement.def_type? &&
            statement.method?(:now) && statement.arguments.empty?
        end

        def file_defines_now_from_clock?
          root = processed_source.ast
          return false unless root

          root.each_node(:block, :def).any? do |definition|
            (let_named?(definition, :now) || now_def?(definition)) && clock_body?(definition.body)
          end
        end

        def clock_body?(body)
          return false unless body

          calls = body.each_node(:send, :csend).to_a
          !open_day_helper_used?(calls) && calls.any? { |call| duration_read?(call) || clock_read?(call) }
        end
      end
    end
  end
end
