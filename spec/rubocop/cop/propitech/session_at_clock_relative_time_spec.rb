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

    it "does not follow a local variable or a let name" do
      expect_no_offenses(<<~RUBY)
        start = 2.hours.ago
        create(:occurrence, starts_at: start)
        create(:occurrence, starts_at: session_start)
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
