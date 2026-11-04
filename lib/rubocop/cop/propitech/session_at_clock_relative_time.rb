# frozen_string_literal: true

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
      # `tomorrow` (also `Time.zone.now` and `Time.zone.today`); or a bare `yesterday`. Arithmetic on such a
      # form (`Time.current + 1.hour`, `3.hours.from_now + 1.day`) is clock-relative too.
      #
      # The call is left alone when it is inside an example or group call (`describe`, `context`, `it` and the
      # like) tagged `:open_day`, inside a `travel_to` block, or when the value uses `open_days_from_now`,
      # `open_days_ago`, `open_day_on_or_after`, `open_day_on_or_before` or `open_day_noon`.
      #
      # The cop reads one expression at a time. It does not follow a local variable, a `let` name or a
      # method call: `starts_at: start` with `start = 2.hours.ago` is not reported, and neither is a
      # factory called through a helper method.
      # @example
      #   # bad
      #   create(:occurrence, starts_at: 2.hours.from_now)
      #   build(:occurrence, ends_at: Time.current + 1.hour)
      #   create(:occurrence, starts_at: Date.yesterday.noon)
      #
      #   # good
      #   create(:occurrence, starts_at: open_days_from_now(2))
      #   create(:occurrence, starts_at: open_day_noon)
      #   it "lists today's sessions", :open_day do
      #     create(:occurrence, starts_at: 2.hours.from_now)
      #   end
      #   travel_to(open_day_noon) { create(:occurrence, starts_at: 1.hour.ago) }
      class SessionAtClockRelativeTime < Base
        MSG = "Do not build a session at a clock-relative time: `Occurrence` validates `:closed_weekday`, " \
              "Sunday is closed, and the spec fails with \"Starts at falls on a day the school is closed\" " \
              "when it runs next to a closed day. Build it with `open_days_from_now`, `open_days_ago`, " \
              "`open_day_on_or_after`, `open_day_on_or_before` or `open_day_noon`, tag the example " \
              "`:open_day`, or wrap it in `travel_to`."

        DEFAULTS = {
          "Factories" => %w[occurrence]
        }.freeze

        FACTORY_METHODS = %i[create build build_stubbed create_list build_list].freeze
        RESTRICT_ON_SEND = FACTORY_METHODS

        TIME_KEYS = %i[starts_at ends_at].freeze
        DURATION_METHODS = %i[ago from_now since until].freeze
        CLOCK_CLASSES = %i[Time DateTime Date].freeze
        CLOCK_READS = %i[current now today yesterday tomorrow].freeze
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

        def on_send(node)
          return unless factory_call?(node) && session_factory?(node)

          time_values(node).each do |value|
            add_offense(value) if clock_relative?(value) && !open_day_context?(node)
          end
        end
        alias on_csend on_send

        private

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

        def clock_relative?(value)
          calls = value.each_node(:send, :csend).to_a
          return false if calls.any? { |call| OPEN_DAY_HELPERS.include?(call.method_name) }

          calls.any? { |call| duration_read?(call) || clock_read?(call) }
        end

        # `ago`, `from_now`, `since` and `until` read the clock only without an argument:
        # `1.day.ago(fixed_time)` counts back from the given time.
        def duration_read?(call)
          DURATION_METHODS.include?(call.method_name) && call.arguments.empty?
        end

        def open_day_context?(node)
          node.each_ancestor(:block, :numblock).any? do |block|
            call = block.send_node
            call.method?(:travel_to) || (EXAMPLE_METHODS.include?(call.method_name) && open_day_tagged?(call))
          end
        end

        def open_day_tagged?(call)
          call.arguments.any? do |argument|
            if argument.hash_type?
              argument.pairs.any? { |pair| pair.key.sym_type? && pair.key.value == OPEN_DAY_TAG && !falsy?(pair.value) }
            else
              argument.sym_type? && argument.value == OPEN_DAY_TAG
            end
          end
        end

        def falsy?(value)
          value.false_type? || value.nil_type?
        end

        def factories
          Array(cop_config.fetch("Factories", DEFAULTS.fetch("Factories"))).map { |name| name.to_s.delete_prefix(":") }
        end
      end
    end
  end
end
