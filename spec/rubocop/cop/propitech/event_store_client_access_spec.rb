# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"

RSpec.describe RuboCop::Cop::Propitech::EventStoreClientAccess, :config do
  def const_message(name, publisher: "DomainEvents::Publisher")
    format(described_class::MSG_CONST, name: name, publisher: publisher)
  end

  def client_message(name, publisher: "DomainEvents::Publisher")
    format(described_class::MSG_CLIENT, name: name, publisher: publisher)
  end

  it "flags the client read from Rails.configuration" do
    expect_offense(<<~RUBY)
      Rails.configuration.event_store.publish(event)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{client_message("Rails.configuration.event_store")}
    RUBY
  end

  it "flags the client read from Rails.application.config" do
    expect_offense(<<~RUBY)
      Rails.application.config.event_store.read.to_a
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{client_message("Rails.application.config.event_store")}
    RUBY
  end

  it "flags the client read through safe navigation" do
    expect_offense(<<~RUBY)
      Rails.configuration&.event_store.publish(event)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{client_message("Rails.configuration&.event_store")}
    RUBY
  end

  it "flags the client read through safe navigation all the way down" do
    expect_offense(<<~RUBY)
      Rails.application&.config&.event_store&.read
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{client_message("Rails.application&.config&.event_store")}
    RUBY
  end

  it "flags the client stubbed in a spec" do
    expect_offense(<<~RUBY)
      allow(Rails.configuration.event_store).to receive(:publish)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{client_message("Rails.configuration.event_store")}
    RUBY
  end

  it "flags the client being replaced" do
    expect_offense(<<~RUBY)
      Rails.configuration.event_store = build_client
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{client_message("Rails.configuration.event_store")}
    RUBY
  end

  it "flags a RubyEventStore constant" do
    expect_offense(<<~RUBY)
      rescue_from RubyEventStore::EventNotFound, with: :not_found
                  ^^^^^^^^^^^^^^ #{const_message("RubyEventStore")}
    RUBY
  end

  it "flags a top-level RailsEventStore constant, such as the browser mount" do
    expect_offense(<<~RUBY)
      mount ::RailsEventStore::Browser, at: "/event_store"
            ^^^^^^^^^^^^^^^^^ #{const_message("RailsEventStore")}
    RUBY
  end

  it "flags the library's namespace on its own" do
    expect_offense(<<~RUBY)
      publisher.publish(RubyEventStore::Event, data: {})
                        ^^^^^^^^^^^^^^ #{const_message("RubyEventStore")}
    RUBY
  end

  it "allows publishing through the DomainEvents wrapper" do
    expect_no_offenses(<<~RUBY)
      EventPublisher.new(actor: user).publish(DomainEvents::Booking::Booked, data: {booking_id: 1})
      DomainEvents.find(event_id)
    RUBY
  end

  it "allows a constant of the same name nested under another namespace" do
    expect_no_offenses("Vendor::RubyEventStore::Client.new")
  end

  it "allows another Rails configuration value" do
    expect_no_offenses("Rails.configuration.active_job.queue_adapter")
  end

  it "allows an event_store method on any other receiver" do
    expect_no_offenses("event_store.read.to_a")
  end

  context "with the options overridden" do
    let(:cop_config) do
      {
        "Namespaces" => ["EventStore"],
        "ClientAccessors" => ["bus"],
        "Publisher" => "Events::Publish"
      }
    end

    it "flags the configured namespace with the configured publisher in the message" do
      expect_offense(<<~RUBY)
        EventStore::Client.new
        ^^^^^^^^^^ #{const_message("EventStore", publisher: "Events::Publish")}
      RUBY
    end

    it "flags the configured client accessor" do
      expect_offense(<<~RUBY)
        Rails.configuration.bus.publish(event)
        ^^^^^^^^^^^^^^^^^^^^^^^ #{client_message("Rails.configuration.bus", publisher: "Events::Publish")}
      RUBY
    end

    it "allows the default namespace it no longer names" do
      expect_no_offenses("RubyEventStore::Event")
    end
  end
end
