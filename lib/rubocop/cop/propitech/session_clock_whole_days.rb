# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Reads a value for a whole number of days from the clock, for `SessionAtClockRelativeTime` inside an
      # `:open_day` example (only today is an open day there, so an hour or minute offset stays allowed). The
      # host cop supplies `duration_read?`, `clock_call?` and `open_day_helper_used?`.
      module SessionClockWholeDays
        extend RuboCop::AST::NodePattern::Macros

        DAY_UNITS = %i[day days week weeks].freeze
        DAY_SHIFTS = %i[tomorrow yesterday].freeze
        ARITHMETIC = %i[+ -].freeze

        def_node_matcher :date_read?, <<~PATTERN
          {
            (send (const {nil? cbase} :Date) {:current :today})
            (send (send (const {nil? cbase} :Time) :zone) :today)
          }
        PATTERN

        def_node_matcher :date_shift?, <<~PATTERN
          (send (const {nil? cbase} :Date) {:tomorrow :yesterday})
        PATTERN

        private

        def whole_days?(value)
          calls = value.each_node(:send, :csend).to_a
          return false if open_day_helper_used?(calls)

          calls.any? { |call| whole_days_step?(call) }
        end

        def whole_days_step?(call)
          return day_duration?(call.receiver) if duration_read?(call)
          return true if date_shift?(call) || (call.method?(:yesterday) && call.receiver.nil?)
          return clock_expression?(call.receiver) if DAY_SHIFTS.include?(call.method_name) && call.receiver

          day_arithmetic?(call)
        end

        def day_arithmetic?(call)
          return false unless ARITHMETIC.include?(call.method_name)

          day_step_on_clock?(call) || (date_read?(call.receiver) && whole_integer?(call.first_argument))
        end

        def day_step_on_clock?(call)
          left = call.receiver
          right = call.first_argument
          (day_duration?(right) && clock_expression?(left)) ||
            (call.method?(:+) && day_duration?(left) && clock_expression?(right))
        end

        def day_duration?(node)
          return false unless node&.call_type? && DAY_UNITS.include?(node.method_name) && node.receiver

          !zero?(node.receiver)
        end

        def whole_integer?(node)
          node&.int_type? && !zero?(node)
        end

        def zero?(node)
          node.numeric_type? && node.value.zero?
        end

        def clock_expression?(node)
          node.each_node(:send, :csend).any? { |call| duration_read?(call) || clock_call?(call) }
        end
      end
    end
  end
end
