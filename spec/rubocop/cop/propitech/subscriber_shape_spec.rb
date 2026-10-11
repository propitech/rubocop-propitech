# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"

RSpec.describe RuboCop::Cop::Propitech::SubscriberShape, :config do
  def place_message(name, directory: "app/jobs")
    format(described_class::MSG_PLACE, name: name, suffix: "Subscriber", directory: directory,
                                       file_suffix: "subscriber")
  end

  def base_message(name, base: "DomainEvents::Subscriber")
    format(described_class::MSG_BASE, name: name, base: base)
  end

  def chain_message(name)
    format(described_class::MSG_CHAIN, name: name)
  end

  def foreign_message(command, name, domain, command_domain)
    format(described_class::MSG_FOREIGN, command: command, name: name, domain: domain,
                                         command_domain: command_domain)
  end

  context "with the place of a subscriber" do
    it "passes a subscriber in its domain module at the generator's path" do
      expect_no_offenses(<<~RUBY, "app/jobs/plans/broadcast_catalogue_subscriber.rb")
        module Plans
          class BroadcastCatalogueSubscriber < DomainEvents::Subscriber
            def handle(event)
              Commands::Plans::RedrawCatalogue.call(run_id: event.data.fetch(:run_id))
            end
          end
        end
      RUBY
    end

    it "passes a compact name and an absolute base class" do
      expect_no_offenses(<<~RUBY, "app/jobs/platform_billing/settle_invoice_subscriber.rb")
        class PlatformBilling::SettleInvoiceSubscriber < ::DomainEvents::Subscriber; end
      RUBY
    end

    it "flags a subscriber in no domain module" do
      expect_offense(<<~RUBY, "app/jobs/authorization_disconnect_subscriber.rb")
        class AuthorizationDisconnectSubscriber < DomainEvents::Subscriber
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{place_message("AuthorizationDisconnectSubscriber")}
        end
      RUBY
    end

    it "flags a subscriber nested one module too deep" do
      expect_offense(<<~RUBY, "app/jobs/plans/catalogue/redraw_subscriber.rb")
        module Plans
          module Catalogue
            class RedrawSubscriber < DomainEvents::Subscriber; end
                  ^^^^^^^^^^^^^^^^ #{place_message("Plans::Catalogue::RedrawSubscriber")}
          end
        end
      RUBY
    end

    it "flags a subscriber whose name lacks the suffix" do
      expect_offense(<<~RUBY, "app/jobs/plans/redraw.rb")
        module Plans
          class Redraw < DomainEvents::Subscriber; end
                ^^^^^^ #{place_message("Plans::Redraw")}
        end
      RUBY
    end

    it "flags a subscriber outside the subscribers directory" do
      expect_offense(<<~RUBY, "app/business_logic/plans/redraw_subscriber.rb")
        module Plans
          class RedrawSubscriber < DomainEvents::Subscriber; end
                ^^^^^^^^^^^^^^^^ #{place_message("Plans::RedrawSubscriber")}
        end
      RUBY
    end

    it "flags a subscriber whose file does not match its name" do
      expect_offense(<<~RUBY, "app/jobs/bookings/redraw_subscriber.rb")
        module Plans
          class RedrawSubscriber < DomainEvents::Subscriber; end
                ^^^^^^^^^^^^^^^^ #{place_message("Plans::RedrawSubscriber")}
        end
      RUBY
    end

    it "checks only the name when the source has no file" do
      expect_no_offenses(<<~RUBY)
        module Plans
          class RedrawSubscriber < DomainEvents::Subscriber; end
        end
      RUBY
    end

    it "passes the subscriber base itself" do
      expect_no_offenses(<<~RUBY, "app/business_logic/domain_events/subscriber.rb")
        module DomainEvents
          class Subscriber < ApplicationJob; end
        end
      RUBY
    end
  end

  context "with the base class of a subscriber" do
    it "flags a class named and placed as a subscriber with another base class" do
      expect_offense(<<~RUBY, "app/jobs/plans/redraw_subscriber.rb")
        module Plans
          class RedrawSubscriber < ApplicationJob; end
                                   ^^^^^^^^^^^^^^ #{base_message("Plans::RedrawSubscriber")}
        end
      RUBY
    end

    it "flags a class named and placed as a subscriber with no base class" do
      expect_offense(<<~RUBY, "app/jobs/plans/redraw_subscriber.rb")
        class Plans::RedrawSubscriber; end
              ^^^^^^^^^^^^^^^^^^^^^^^ #{base_message("Plans::RedrawSubscriber")}
      RUBY
    end

    it "passes a class named as a subscriber outside the subscribers directory" do
      expect_no_offenses(<<~RUBY, "app/models/newsletter_subscriber.rb")
        class NewsletterSubscriber < ApplicationRecord; end
      RUBY
    end

    it "passes a job in the subscribers directory that is not named as a subscriber" do
      expect_no_offenses(<<~RUBY, "app/jobs/plans/broadcast_catalogue_job.rb")
        module Plans
          class BroadcastCatalogueJob < ApplicationJob; end
        end
      RUBY
    end
  end

  context "with a subscriber that publishes" do
    it "flags a publish through the publisher" do
      expect_offense(<<~RUBY)
        module Notifications
          class BookingConfirmationSubscriber < DomainEvents::Subscriber
            def handle(event)
              DomainEvents::Publisher.new.publish(DomainEvents::Notification::Sent, data: {})
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{chain_message("Notifications::BookingConfirmationSubscriber")}
            end
          end
        end
      RUBY
    end

    it "flags a publish through a domain's own publisher" do
      expect_offense(<<~RUBY)
        module Notifications
          class BookingConfirmationSubscriber < DomainEvents::Subscriber
            def handle(event)
              Notifications::EventPublisher.new(actor: nil).publish(event_class, data: {})
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{chain_message("Notifications::BookingConfirmationSubscriber")}
            end
          end
        end
      RUBY
    end

    it "flags a publish of an event class through a held publisher" do
      expect_offense(<<~RUBY)
        module Notifications
          class BookingConfirmationSubscriber < DomainEvents::Subscriber
            def handle(event)
              publisher&.publish(DomainEvents::Notification::Sent, data: {})
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{chain_message("Notifications::BookingConfirmationSubscriber")}
            end
          end
        end
      RUBY
    end

    it "passes a publish outside a subscriber" do
      expect_no_offenses(<<~RUBY)
        module Commands
          module Bookings
            class Book < ApplicationCommand
              def execute
                Bookings::EventPublisher.new(actor: user).publish(DomainEvents::Booking::Booked, data: {})
              end
            end
          end
        end
      RUBY
    end

    it "passes a publish-named call that is no event" do
      expect_no_offenses(<<~RUBY)
        module Plans
          class RedrawSubscriber < DomainEvents::Subscriber
            def handle(event)
              channel.publish(:redraw, event.data)
            end
          end
        end
      RUBY
    end
  end

  context "with the commands a subscriber calls" do
    it "flags a command of another domain" do
      expect_offense(<<~RUBY)
        module Plans
          class RedrawSubscriber < DomainEvents::Subscriber
            def handle(event)
              Commands::Invoices::Create.call(school_id: event.data.fetch(:school_id))
              ^^^^^^^^^^^^^^^^^^^^^^^^^^ #{foreign_message("Commands::Invoices::Create", "Plans::RedrawSubscriber", "Plans", "Invoices")}
            end
          end
        end
      RUBY
    end

    it "flags an absolute reference to a command of another domain" do
      expect_offense(<<~RUBY)
        class Plans::RedrawSubscriber < DomainEvents::Subscriber
          def handle(event)
            ::Commands::Invoices::Create.call
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{foreign_message("Commands::Invoices::Create", "Plans::RedrawSubscriber", "Plans", "Invoices")}
          end
        end
      RUBY
    end

    it "passes a command of its own domain" do
      expect_no_offenses(<<~RUBY)
        module Bookings
          class ReleaseHoldSubscriber < DomainEvents::Subscriber
            def handle(event)
              Commands::Bookings::ReleaseHold.call(booking_id: event.data.fetch(:booking_id))
            end
          end
        end
      RUBY
    end

    it "passes a shared constant directly under the commands namespace" do
      expect_no_offenses(<<~RUBY)
        module Plans
          class RedrawSubscriber < DomainEvents::Subscriber
            include Commands::AdminActor
          end
        end
      RUBY
    end

    it "passes a command call outside a subscriber" do
      expect_no_offenses(<<~RUBY)
        module Commands
          module Enrolments
            class Enrol < ApplicationCommand
              def bill
                Commands::Invoices::Create.call
              end
            end
          end
        end
      RUBY
    end
  end

  context "with other options" do
    let(:cop_config) do
      {
        "BaseClass" => "Events::Handler",
        "Directory" => "app/subscribers",
        "CommandsNamespace" => "Operations"
      }
    end

    it "follows the configured base class, directory and commands namespace" do
      expect_offense(<<~RUBY, "app/subscribers/plans/redraw_subscriber.rb")
        module Plans
          class RedrawSubscriber < Events::Handler
            def handle(event)
              Operations::Invoices::Create.call
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{foreign_message("Operations::Invoices::Create", "Plans::RedrawSubscriber", "Plans", "Invoices")}
              Commands::Invoices::Create.call
            end
          end
        end
      RUBY
    end

    it "reports the configured place" do
      expect_offense(<<~RUBY, "app/jobs/plans/redraw_subscriber.rb")
        module Plans
          class RedrawSubscriber < Events::Handler; end
                ^^^^^^^^^^^^^^^^ #{place_message("Plans::RedrawSubscriber", directory: "app/subscribers")}
        end
      RUBY
    end
  end
end
