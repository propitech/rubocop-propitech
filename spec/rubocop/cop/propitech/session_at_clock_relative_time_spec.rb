# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"

RSpec.describe RuboCop::Cop::Propitech::SessionAtClockRelativeTime, :config do
  let(:cop_config) { { "Factories" => %w[occurrence] } }

  def message
    described_class::MSG
  end

  it "names the closed-day failure and the helpers in the message" do
    expect(message).to include("closed", "open_days_from_now", "open_day_noon", ":open_day", "travel_to")
  end

  describe "flagged forms" do
    it "flags a duration from now or ago on starts_at and ends_at" do
      expect_offense(<<~RUBY)
        create(:occurrence, starts_at: 2.hours.from_now, ends_at: 3.hours.from_now)
                                       ^^^^^^^^^^^^^^^^ #{message}
                                                                  ^^^^^^^^^^^^^^^^ #{message}
        build(:occurrence, starts_at: 30.minutes.ago)
                                      ^^^^^^^^^^^^^^ #{message}
        create(:occurrence, starts_at: 3.days.from_now)
                                       ^^^^^^^^^^^^^^^ #{message}
      RUBY
    end

    it "flags Time.current arithmetic" do
      expect_offense(<<~RUBY)
        create(:occurrence, starts_at: Time.current + 1.hour)
                                       ^^^^^^^^^^^^^^^^^^^^^ #{message}
      RUBY
    end

    it "flags a duration since" do
      expect_offense(<<~RUBY)
        create(:occurrence, starts_at: 2.days.since)
                                       ^^^^^^^^^^^^ #{message}
      RUBY
    end

    it "flags yesterday, Date.yesterday, Date.current - 1 and 1.day.ago" do
      expect_offense(<<~RUBY)
        create(:occurrence, starts_at: yesterday)
                                       ^^^^^^^^^ #{message}
        create(:occurrence, starts_at: Date.yesterday)
                                       ^^^^^^^^^^^^^^ #{message}
        create(:occurrence, starts_at: Date.current - 1)
                                       ^^^^^^^^^^^^^^^^ #{message}
        create(:occurrence, starts_at: 1.day.ago)
                                       ^^^^^^^^^ #{message}
      RUBY
    end

    it "flags other clock reads" do
      expect_offense(<<~RUBY)
        create(:occurrence, starts_at: Time.zone.now)
                                       ^^^^^^^^^^^^^ #{message}
        create(:occurrence, starts_at: DateTime.now)
                                       ^^^^^^^^^^^^ #{message}
        create(:occurrence, starts_at: ::Time.now)
                                       ^^^^^^^^^^ #{message}
      RUBY
    end

    it "flags a clock form nested in a larger expression" do
      expect_offense(<<~RUBY)
        create(:occurrence, starts_at: (3.hours.from_now + 1.day).change(min: 0))
                                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
      RUBY
    end

    it "flags the other factory methods, bare or on FactoryBot" do
      expect_offense(<<~RUBY)
        build_stubbed(:occurrence, starts_at: 1.hour.ago)
                                              ^^^^^^^^^^ #{message}
        create_list(:occurrence, 3, starts_at: 1.hour.ago)
                                               ^^^^^^^^^^ #{message}
        build_list(:occurrence, 3, starts_at: 1.hour.ago)
                                              ^^^^^^^^^^ #{message}
        FactoryBot.create(:occurrence, starts_at: 1.hour.ago)
                                                  ^^^^^^^^^^ #{message}
        ::FactoryBot.build(:occurrence, starts_at: 1.hour.ago)
                                                   ^^^^^^^^^^ #{message}
      RUBY
    end

    it "flags a call that also names a trait and a string factory name" do
      expect_offense(<<~RUBY)
        create(:occurrence, :published, starts_at: 1.hour.ago, capacity: 4)
                                                   ^^^^^^^^^^ #{message}
        create("occurrence", starts_at: 1.hour.ago)
                                        ^^^^^^^^^^ #{message}
      RUBY
    end

    it "flags a call inside an example that is not tagged" do
      expect_offense(<<~RUBY)
        it "lists it", :slow do
          create(:occurrence, starts_at: 1.hour.ago)
                                         ^^^^^^^^^^ #{message}
        end
      RUBY
    end
  end

  it "flags a let named open_day, which is not an example or group tag" do
    expect_offense(<<~RUBY)
      let(:open_day) { create(:occurrence, starts_at: 1.hour.ago) }
                                                      ^^^^^^^^^^ #{message}
    RUBY
  end

  describe "allowed forms" do
    it "ignores a call inside an example tagged :open_day" do
      expect_no_offenses(<<~RUBY)
        it "lists today's sessions", :open_day do
          create(:occurrence, starts_at: 2.hours.from_now)
        end
      RUBY
    end

    it "ignores a call inside any example or group method tagged :open_day" do
      expect_no_offenses(<<~RUBY)
        shared_examples_for "sessions", :open_day do
          create(:occurrence, starts_at: 1.hour.ago)
        end
        example_group "Sessions", :open_day do
          create(:occurrence, starts_at: 1.hour.ago)
        end
        pending "later", :open_day do
          create(:occurrence, starts_at: 1.hour.ago)
        end
      RUBY
    end

    it "ignores a call inside a group tagged :open_day, bare or as metadata" do
      expect_no_offenses(<<~RUBY)
        describe "Sessions", :open_day do
          it "lists them" do
            create(:occurrence, starts_at: 2.hours.from_now)
          end
        end
        context "Sessions", open_day: true do
          let(:session) { build(:occurrence, ends_at: Time.current + 1.hour) }
        end
      RUBY
    end

    it "flags a group whose open_day metadata is false" do
      expect_offense(<<~RUBY)
        context "Sessions", open_day: false do
          create(:occurrence, starts_at: 1.hour.ago)
                                         ^^^^^^^^^^ #{message}
        end
      RUBY
    end

    it "ignores a call inside a travel_to block" do
      expect_no_offenses(<<~RUBY)
        travel_to(open_day_noon) do
          create(:occurrence, starts_at: 1.hour.ago)
        end
        travel_to(Time.zone.local(2026, 11, 2)) { create(:occurrence, starts_at: Time.current + 1.hour) }
      RUBY
    end

    it "ignores a time built from an open-day helper" do
      expect_no_offenses(<<~RUBY)
        create(:occurrence, starts_at: open_days_from_now(2))
        create(:occurrence, starts_at: open_days_ago(1), ends_at: open_days_ago(1) + 1.hour)
        create(:occurrence, starts_at: open_day_on_or_after(Date.current))
        create(:occurrence, starts_at: open_day_on_or_before(Date.current).change(hour: 9))
        create(:occurrence, starts_at: open_day_noon)
      RUBY
    end

    it "ignores a duration given a fixed time as its argument" do
      expect_no_offenses(<<~RUBY)
        create(:occurrence, starts_at: Time.zone.local(2026, 11, 2, 10).since(1.hour))
        create(:occurrence, starts_at: 2.hours.since(Time.zone.local(2026, 11, 2, 10)))
        create(:occurrence, starts_at: 1.day.ago(Time.zone.local(2026, 11, 3, 10)))
      RUBY
    end

    it "ignores a fixed time" do
      expect_no_offenses(<<~RUBY)
        create(:occurrence, starts_at: Time.zone.local(2026, 11, 2, 10), ends_at: Time.zone.parse("2026-11-02 11:00"))
      RUBY
    end

    it "ignores a clock-relative value on another key" do
      expect_no_offenses(<<~RUBY)
        create(:occurrence, published_at: 1.hour.ago)
        create(:occurrence, "starts_at" => 1.hour.ago)
      RUBY
    end

    it "ignores a factory not named in Factories" do
      expect_no_offenses(<<~RUBY)
        create(:invoice, starts_at: 1.hour.ago)
        create(starts_at: 1.hour.ago)
        create(name, starts_at: 1.hour.ago)
        other.create(:occurrence, starts_at: 1.hour.ago)
      RUBY
    end

    it "ignores a name with no let or local definition, and a method call" do
      expect_no_offenses(<<~RUBY)
        create(:occurrence, starts_at: session_start)
        create(:occurrence, starts_at: session_start(open_day_noon))
        create(:occurrence, starts_at: helper.start)
      RUBY
    end

    it "ignores a let or local that is not built from the clock" do
      expect_no_offenses(<<~RUBY)
        describe "Sessions" do
          let(:session_start) { open_days_from_now(2) }
          let(:session_end) { Time.zone.local(2026, 11, 2, 10) }

          it "lists them" do
            start = open_day_noon
            create(:occurrence, starts_at: session_start, ends_at: session_end)
            create(:occurrence, starts_at: start)
          end
        end
      RUBY
    end

    it "ignores a clock-relative let or local inside a travel_to block" do
      expect_no_offenses(<<~RUBY)
        let(:session_start) { 2.hours.ago }
        travel_to(open_day_noon) do
          create(:occurrence, starts_at: session_start)
        end
      RUBY
    end

    it "ignores a bare now the file does not define from the clock" do
      expect_no_offenses(<<~RUBY)
        let(:now) { open_day_noon }
        create(:occurrence, starts_at: now + 2.hours)
        create(:occurrence, starts_at: now)
      RUBY
    end

    it "ignores a bare now built from a fixed date" do
      expect_no_offenses(<<~RUBY)
        def now
          Time.zone.local(2026, 11, 2, 10)
        end
        create(:occurrence, starts_at: now + 2.days)
      RUBY
    end

    it "ignores a bare now when the file never defines it" do
      expect_no_offenses(<<~RUBY)
        create(:occurrence, starts_at: now + 2.hours)
      RUBY
    end

    it "does not take a local from another example when a block parameter has the name" do
      expect_no_offenses(<<~RUBY)
        it "a" do
          start = 2.hours.ago
          expect(start).to be_present
        end
        it "b" do
          [open_day_noon].each do |start|
            create(:occurrence, starts_at: start)
          end
        end
      RUBY
    end

    it "does not take a local from another example when a method parameter has the name" do
      expect_no_offenses(<<~RUBY)
        it "a" do
          start = 2.hours.ago
          expect(start).to be_present
        end
        def make_session(start)
          create(:occurrence, starts_at: start)
        end
      RUBY
    end

    it "does not take a local assigned outside the enclosing def" do
      expect_no_offenses(<<~RUBY)
        start = 2.hours.ago
        def make_session
          create(:occurrence, starts_at: start)
        end
      RUBY
    end

    it "reads a bare now by the nearest group that defines it" do
      expect_no_offenses(<<~RUBY)
        describe "a" do
          let(:now) { Time.current }
        end
        describe "b" do
          let(:now) { open_day_noon }

          it "x" do
            create(:occurrence, starts_at: now + 2.hours)
          end
        end
      RUBY
    end

    it "ignores an open-day helper given a clock value held in a let" do
      expect_no_offenses(<<~RUBY)
        let(:today) { Date.current }
        create(:occurrence, starts_at: open_day_on_or_after(today))
      RUBY
    end

    it "does not follow a let through a second let" do
      expect_no_offenses(<<~RUBY)
        let(:base) { 2.hours.ago }
        let(:session_start) { base }
        create(:occurrence, starts_at: session_start)
      RUBY
    end

    it "ignores hour and minute offsets inside an :open_day example" do
      expect_no_offenses(<<~RUBY)
        it "lists today's sessions", :open_day do
          create(:occurrence, starts_at: 0.days.ago, ends_at: 30.minutes.from_now)
          create(:occurrence, starts_at: Time.current + 2.hours)
          create(:occurrence, starts_at: Date.current + 0)
        end
      RUBY
    end
  end

  describe "whole days inside an :open_day example" do
    it "flags a day-sized duration" do
      expect_offense(<<~RUBY)
        it "lists them", :open_day do
          create(:occurrence, starts_at: 2.days.from_now)
                                         ^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: 1.day.ago.change(hour: 9))
                                         ^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: 1.week.from_now.noon)
                                         ^^^^^^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: 2.weeks.since.beginning_of_day)
                                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: 3.days.until)
                                         ^^^^^^^^^^^^ #{message}
        end
      RUBY
    end

    it "flags a day-sized step added to or taken from a clock read" do
      expect_offense(<<~RUBY)
        describe "Sessions", :open_day do
          create(:occurrence, starts_at: Time.current + 2.days)
                                         ^^^^^^^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: Time.zone.now - 1.week)
                                         ^^^^^^^^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: 2.days + Time.current)
                                         ^^^^^^^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: 3.hours.from_now + 1.day)
                                         ^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
        end
      RUBY
    end

    it "flags Date.tomorrow, Date.yesterday, Time.current.tomorrow and Date.current plus an integer" do
      expect_offense(<<~RUBY)
        it "lists them", :open_day do
          create(:occurrence, starts_at: Date.tomorrow)
                                         ^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: Date.yesterday.noon)
                                         ^^^^^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: Time.current.tomorrow)
                                         ^^^^^^^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: Date.current + 2)
                                         ^^^^^^^^^^^^^^^^ #{message}
          create(:occurrence, starts_at: Date.current - 1)
                                         ^^^^^^^^^^^^^^^^ #{message}
        end
      RUBY
    end

    it "flags a day-sized step inside a group tagged with open_day metadata" do
      expect_offense(<<~RUBY)
        context "Sessions", open_day: true do
          let(:session) { build(:occurrence, ends_at: 2.days.from_now) }
                                                      ^^^^^^^^^^^^^^^ #{message}
        end
      RUBY
    end

    it "flags a day-sized step reached through a let or a local" do
      expect_offense(<<~RUBY)
        describe "Sessions" do
          let(:session_start) { 2.days.from_now }

          it "lists them", :open_day do
            later = Time.current + 1.week
            create(:occurrence, starts_at: session_start)
                                           ^^^^^^^^^^^^^ #{message}
            create(:occurrence, starts_at: later)
                                           ^^^^^ #{message}
          end
        end
      RUBY
    end

    it "flags a day step added to a clock value held in a local" do
      expect_offense(<<~RUBY)
        it "lists them", :open_day do
          today = Date.current
          create(:occurrence, starts_at: today + 2)
                                         ^^^^^^^^^ #{message}
        end
      RUBY
    end

    it "flags a day-sized step added to a clock value held in a let" do
      expect_offense(<<~RUBY)
        describe "Sessions" do
          let(:start) { Time.current }

          it "lists them", :open_day do
            create(:occurrence, starts_at: start + 2.days)
                                           ^^^^^^^^^^^^^^ #{message}
          end
        end
      RUBY
    end

    it "ignores an hour offset added to a clock value held in a let" do
      expect_no_offenses(<<~RUBY)
        describe "Sessions" do
          let(:start) { Time.current }

          it "lists them", :open_day do
            create(:occurrence, starts_at: start + 2.hours)
          end
        end
      RUBY
    end

    it "flags a bare now defined from the clock plus a day-sized step" do
      expect_offense(<<~RUBY)
        let(:now) { Time.current }
        it "lists them", :open_day do
          create(:occurrence, starts_at: now + 2.days)
                                         ^^^^^^^^^^^^ #{message}
        end
      RUBY
    end
  end

  describe "following a let or a local variable" do
    it "flags a value that names a let built from the clock, once on the value" do
      expect_offense(<<~RUBY)
        describe "Sessions" do
          let(:session_start) { 2.hours.from_now }

          it "lists them" do
            create(:occurrence, starts_at: session_start, ends_at: session_start + 1.hour)
                                           ^^^^^^^^^^^^^ #{message}
                                                                   ^^^^^^^^^^^^^^^^^^^^^^ #{message}
          end
        end
      RUBY
    end

    it "flags a let! and a let defined in an enclosing group" do
      expect_offense(<<~RUBY)
        describe "Sessions" do
          let!(:session_start) { Time.current + 1.hour }

          context "later" do
            it "lists them" do
              create(:occurrence, starts_at: session_start)
                                             ^^^^^^^^^^^^^ #{message}
            end
          end
        end
      RUBY
    end

    it "uses the nearest group that defines the let" do
      expect_no_offenses(<<~RUBY)
        describe "Sessions" do
          let(:session_start) { 2.hours.from_now }

          context "fixed" do
            let(:session_start) { open_days_from_now(2) }

            it "lists them" do
              create(:occurrence, starts_at: session_start)
            end
          end
        end
      RUBY
    end

    it "flags a local variable assigned earlier in the same block" do
      expect_offense(<<~RUBY)
        it "lists them" do
          start = 2.hours.ago
          create(:occurrence, starts_at: start)
                                         ^^^^^ #{message}
        end
      RUBY
    end

    it "flags a local variable assigned at the top of the file" do
      expect_offense(<<~RUBY)
        start = 2.hours.ago
        create(:occurrence, starts_at: start)
                                       ^^^^^ #{message}
      RUBY
    end

    it "flags a local variable from the enclosing block when the call is in a nested block" do
      expect_offense(<<~RUBY)
        it "lists them" do
          start = 2.hours.ago
          3.times { create(:occurrence, starts_at: start) }
                                                   ^^^^^ #{message}
        end
      RUBY
    end

    it "flags a block parameter reassigned in the same block before the call" do
      expect_offense(<<~RUBY)
        [open_day_noon].each do |start|
          start = 2.hours.ago
          create(:occurrence, starts_at: start)
                                         ^^^^^ #{message}
        end
      RUBY
    end

    it "flags a bare now defined from the clock with let or def" do
      expect_offense(<<~RUBY)
        let(:now) { Time.current }
        create(:occurrence, starts_at: now + 2.hours)
                                       ^^^^^^^^^^^^^ #{message}
      RUBY

      expect_offense(<<~RUBY)
        def now
          Time.zone.now
        end
        create(:occurrence, starts_at: now)
                                       ^^^ #{message}
      RUBY
    end
  end

  describe "Factories option" do
    let(:cop_config) { { "Factories" => %w[occurrence recurring_occurrence] } }

    it "checks every configured factory" do
      expect_offense(<<~RUBY)
        create(:recurring_occurrence, starts_at: 1.hour.ago)
                                                 ^^^^^^^^^^ #{message}
        create(:occurrence, starts_at: 1.hour.ago)
                                       ^^^^^^^^^^ #{message}
        create(:invoice, starts_at: 1.hour.ago)
      RUBY
    end
  end

  describe "default Factories" do
    let(:cop_config) { {} }

    it "checks occurrence only" do
      expect_offense(<<~RUBY)
        create(:occurrence, starts_at: 1.hour.ago)
                                       ^^^^^^^^^^ #{message}
        create(:recurring_occurrence, starts_at: 1.hour.ago)
      RUBY
    end
  end
end
