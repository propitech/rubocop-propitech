# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"

RSpec.describe RuboCop::Cop::Propitech::EventName, :config do
  def place_message(name, namespace: "DomainEvents")
    format(described_class::MSG_PLACE, name: name, namespace: namespace)
  end

  def tense_message(name)
    format(described_class::MSG_TENSE, name: name, namespace: "DomainEvents")
  end

  it "flags a fact in the present tense" do
    expect_offense(<<~RUBY)
      module DomainEvents
        module Booking
          class Book < Event
                ^^^^ #{tense_message("DomainEvents::Booking::Book")}
          end
        end
      end
    RUBY
  end

  it "flags an instruction named as an event" do
    expect_offense(<<~RUBY)
      module DomainEvents
        module Notification
          class SendEmail < Event
                ^^^^^^^^^ #{tense_message("DomainEvents::Notification::SendEmail")}
          end
        end
      end
    RUBY
  end

  it "flags a word ending in -eed that is not a participle" do
    expect_offense(<<~RUBY)
      module DomainEvents
        module Catalogue
          class ProductFeed < Event
                ^^^^^^^^^^^ #{tense_message("DomainEvents::Catalogue::ProductFeed")}
          end
        end
      end
    RUBY
  end

  it "flags a short word ending in -ed" do
    expect_offense(<<~RUBY)
      class DomainEvents::Booking::Red < DomainEvents::Event
                                   ^^^ #{tense_message("DomainEvents::Booking::Red")}
      end
    RUBY
  end

  it "flags an event declared directly under the namespace, with no domain" do
    expect_offense(<<~RUBY)
      module DomainEvents
        class Booked < Event
              ^^^^^^ #{place_message("DomainEvents::Booked")}
        end
      end
    RUBY
  end

  it "flags an event nested one module too deep" do
    expect_offense(<<~RUBY)
      module DomainEvents
        module Booking
          module Drop
            class Booked < Event
                  ^^^^^^ #{place_message("DomainEvents::Booking::Drop::Booked")}
            end
          end
        end
      end
    RUBY
  end

  it "flags an event outside the namespace" do
    expect_offense(<<~RUBY)
      module Bookings
        class Booked < DomainEvents::Event
              ^^^^^^ #{place_message("Bookings::Booked")}
        end
      end
    RUBY
  end

  it "flags an event declared with a top-level path elsewhere" do
    expect_offense(<<~RUBY)
      module DomainEvents
        class ::Booking::Booked < ::DomainEvents::Event
              ^^^^^^^^^^^^^^^^^ #{place_message("Booking::Booked")}
        end
      end
    RUBY
  end

  it "allows a fact in the past tense" do
    expect_no_offenses(<<~RUBY)
      module DomainEvents
        module Booking
          class Booked < Event
          end
        end
      end
    RUBY
  end

  it "allows a compound fact whose last word is in the past tense" do
    expect_no_offenses(<<~RUBY)
      module DomainEvents
        module Plan
          class MigrationRunStateChanged < Event
          end
        end
      end
    RUBY
  end

  it "allows an irregular participle, with or without a prefix" do
    expect_no_offenses(<<~RUBY)
      module DomainEvents
        module Invoice
          class Paid < Event; end
          class Overpaid < Event; end
          class Withdrawn < Event; end
          class LotDrawn < Event; end
          class Reset < Event; end
        end
      end
    RUBY
  end

  it "allows the compact and fully qualified forms" do
    expect_no_offenses(<<~RUBY)
      class DomainEvents::Booking::Booked < DomainEvents::Event; end
      module DomainEvents::Booking
        class Cancelled < ::DomainEvents::Event; end
      end
    RUBY
  end

  it "allows an acronym before the participle" do
    expect_no_offenses(<<~RUBY)
      class DomainEvents::Report::PDFRendered < DomainEvents::Event; end
    RUBY
  end

  it "ignores a bare Event that resolves outside the namespace" do
    expect_no_offenses(<<~RUBY)
      module DomainEvents::Booking
        class Book < Event; end
      end
      class Book < Event; end
    RUBY
  end

  it "ignores a class with another base class" do
    expect_no_offenses(<<~RUBY)
      module DomainEvents
        class Event < RubyEventStore::Event; end
        class Subscriber < ApplicationJob; end
        module Booking
          class Book < ::Event; end
        end
      end
    RUBY
  end

  context "with the options overridden" do
    let(:cop_config) do
      {
        "Namespace" => "Events",
        "BaseClass" => "Fact",
        "PastParticiples" => ["dealt"],
        "ParticiplePrefixes" => [],
        "NotPastTense" => ["shed"]
      }
    end

    it "flags an event of the configured base class in the wrong place" do
      expect_offense(<<~RUBY)
        module Events
          class Booked < Fact; end
                ^^^^^^ #{place_message("Events::Booked", namespace: "Events")}
        end
      RUBY
    end

    it "flags a word listed as not in the past tense" do
      expect_offense(<<~RUBY)
        class Events::Barn::Shed < Events::Fact; end
                            ^^^^ #{tense_message("Events::Barn::Shed")}
      RUBY
    end

    it "reads the configured participles only" do
      expect_offense(<<~RUBY)
        module Events
          module Cards
            class Dealt < Fact; end
            class Paid < Fact; end
                  ^^^^ #{tense_message("Events::Cards::Paid")}
          end
        end
      RUBY
    end

    it "ignores the default base class it no longer names" do
      expect_no_offenses("class DomainEvents::Booking::Book < DomainEvents::Event; end")
    end
  end
end
