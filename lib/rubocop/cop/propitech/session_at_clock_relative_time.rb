# frozen_string_literal: true

require_relative "session_clock_definitions"
require_relative "session_clock_whole_days"

module RuboCop
  module Cop
    module Propitech
      # Flags a session factory call whose `starts_at:` or `ends_at:` is built from the clock. An
      # `Occurrence` validates `:closed_weekday`, and Sunday is a closed day, so a session built at
      # `2.hours.from_now` or `1.day.ago` fails with "Starts at falls on a day the school is closed"
      # whenever the suite runs on the day before or after a closed one (for example `1.day.ago` on a
      # Monday).
      #
      # The cop checks `create`, `build`, `build_stubbed`, `create_list` and `build_list`, bare or on
      # `FactoryBot`, whose first argument is a factory named in `Factories` (default `occurrence`). A
      # value is clock-relative when any of these appears anywhere inside it: `ago`, `from_now`, `since` or
      # `until` on a duration, with no argument (`1.day.ago(fixed_time)` counts from the given time and is
      # left alone); `Time`, `DateTime` or `Date` read with `current`, `now`, `today`, `yesterday` or
      # `tomorrow` (also `Time.zone.now` and `Time.zone.today`); a bare `yesterday`; or a bare `now` where
      # the file defines it from the clock (`let(:now) { Time.current }`, `def now = Time.current`). A `now`
      # built from an open-day helper or a fixed date does not count. Arithmetic on such a form
      # (`Time.current + 1.hour`, `3.hours.from_now + 1.day`) is clock-relative too.
      #
      # The call is left alone when it is inside a `travel_to` block, or when the value uses
      # `open_days_from_now`, `open_days_ago`, `open_day_on_or_after`, `open_day_on_or_before` or
      # `open_day_noon`.
      #
      # Inside an example or group call (`describe`, `context`, `it` and the like) tagged `:open_day`, only
      # today is an open day, so hour and minute offsets are left alone but a whole number of days is still
      # reported. A whole number of days is `N.day`, `N.days`, `N.week` or `N.weeks` (not `0`) with `ago`,
      # `from_now`, `since` or `until` or added to or taken from a clock read; `Date.tomorrow`,
      # `Date.yesterday`, `Time.current.tomorrow`; and `Date.current` plus or minus an integer.
      #
      # The cop follows a value that names a `let` of the same file (the nearest enclosing group that defines
      # it) or a local variable assigned earlier in the same block, one level deep: the name is replaced by
      # its definition once, and a name inside that definition is not followed. It reports once, on the value
      # in the factory call. It does not follow a method call, so a factory called through a helper method
      # is not reported.
      # @example
      #   # bad
      #   create(:occurrence, starts_at: 2.hours.from_now)
      #   build(:occurrence, ends_at: Time.current + 1.hour)
      #   create(:occurrence, starts_at: Date.yesterday.noon)
      #   start = 2.hours.ago
      #   create(:occurrence, starts_at: start)
      #   it "lists them", :open_day do
      #     create(:occurrence, starts_at: 2.days.from_now)
      #   end
      #
      #   # good
      #   create(:occurrence, starts_at: open_days_from_now(2))
      #   create(:occurrence, starts_at: open_day_noon)
      #   it "lists today's sessions", :open_day do
      #     create(:occurrence, starts_at: 2.hours.from_now)
      #   end
      #   travel_to(open_day_noon) { create(:occurrence, starts_at: 1.hour.ago) }
      class SessionAtClockRelativeTime < Base
        include SessionClockDefinitions
        include SessionClockWholeDays

        MSG = "Do not build a session at a clock-relative time: `Occurrence` validates `:closed_weekday`, " \
              "Sunday is closed, and the spec fails with \"Starts at falls on a day the school is closed\" " \
              "when it runs next to a closed day. Build it with `open_days_from_now`, `open_days_ago`, " \
              "`open_day_on_or_after`, `open_day_on_or_before` or `open_day_noon`, tag the example " \
              "`:open_day`, or wrap it in `travel_to`."

        DEFAULTS = { "Factories" => %w[occurrence] }.freeze

        FACTORY_METHODS = %i[create build build_stubbed create_list build_list].freeze
        RESTRICT_ON_SEND = FACTORY_METHODS

        TIME_KEYS = %i[starts_at ends_at].freeze
        DURATION_METHODS = %i[ago from_now since until].freeze
        OPEN_DAY_HELPERS = %i[
          open_days_from_now open_days_ago open_day_on_or_after open_day_on_or_before open_day_noon
        ].freeze
        OPEN_DAY_TAG = :open_day
        EXAMPLE_METHODS = %i[
          describe context feature shared_examples shared_examples_for shared_context example_group
          it specify scenario example its focus pending skip
          fdescribe fcontext ffeature fit fspecify fscenario fexample
          xdescribe xcontext xfeature xit xspecify xscenario xexample
        ].freeze

        def_node_matcher :factory_call?, <<~PATTERN
          (send {nil? (const {nil? cbase} :FactoryBot)} {:create :build :build_stubbed :create_list :build_list} ...)
        PATTERN

        def_node_matcher :clock_read?, <<~PATTERN
          {
            (send (const {nil? cbase} {:Time :DateTime :Date}) {:current :now :today :yesterday :tomorrow})
            (send (send (const {nil? cbase} :Time) :zone) {:now :today})
            (send nil? :yesterday)
          }
        PATTERN

        def on_new_investigation
          @now_from_clock = nil
          @definitions = nil
        end

        def on_send(node)
          return unless factory_call?(node) && session_factory?(node)
          return if travel_to_context?(node)

          whole_days_only = open_day_tagged_context?(node)
          time_values(node).each do |value|
            add_offense(value) if offending?(value, node, whole_days_only)
          end
        end
        alias on_csend on_send

        private

        # One expression: the value with each `let` or local variable it names read as its definition (one level).
        def offending?(value, node, whole_days_only)
          @definitions = definitions_for(value, node)
          calls = calls_of(value)
          return false if open_day_helper_used?(calls)

          calls.any? { |call| whole_days_only ? whole_days_step?(call) : clock_read_step?(call) }
        end

        def clock_read_step?(call)
          duration_read?(call) || clock_call?(call)
        end

        def session_factory?(node)
          name = node.first_argument
          return false unless name&.sym_type? || name&.str_type?

          factories.include?(name.value.to_s)
        end

        def time_values(node)
          node.arguments.select(&:hash_type?).flat_map do |hash|
            hash.pairs.filter_map do |pair|
              pair.value if pair.key.sym_type? && TIME_KEYS.include?(pair.key.value)
            end
          end
        end

        def open_day_helper_used?(calls)
          calls.any? { |call| OPEN_DAY_HELPERS.include?(call.method_name) }
        end

        def clock_call?(call)
          clock_read?(call) || (bare_now?(call) && now_from_clock?(call))
        end

        # `ago`, `from_now`, `since` and `until` read the clock only without an argument:
        # `1.day.ago(fixed_time)` counts back from the given time.
        def duration_read?(call)
          DURATION_METHODS.include?(call.method_name) && call.arguments.empty?
        end

        def travel_to_context?(node)
          node.each_ancestor(:block, :numblock).any? { |block| block.send_node.method?(:travel_to) }
        end

        def open_day_tagged_context?(node)
          node.each_ancestor(:block, :numblock).any? do |block|
            call = block.send_node
            EXAMPLE_METHODS.include?(call.method_name) && open_day_tagged?(call)
          end
        end

        def open_day_tagged?(call)
          call.arguments.any? do |argument|
            if argument.hash_type?
              argument.pairs.any? do |pair|
                pair.key.sym_type? && pair.key.value == OPEN_DAY_TAG && !pair.value.falsey_literal?
              end
            else
              argument.sym_type? && argument.value == OPEN_DAY_TAG
            end
          end
        end

        def factories
          Array(cop_config.fetch("Factories", DEFAULTS.fetch("Factories"))).map { |name| name.to_s.delete_prefix(":") }
        end
      end
    end
  end
end
