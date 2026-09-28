# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"

RSpec.describe RuboCop::Cop::Propitech::CommentBudget, :config do
  it "passes a directive run spanning a shebang and a frozen_string_literal line" do
    expect_no_offenses(<<~RUBY)
      #!/usr/bin/env ruby
      # frozen_string_literal: true
    RUBY
  end

  it "passes an annotaterb schema block placed directly under a magic comment" do
    expect_no_offenses(<<~RUBY)
      # frozen_string_literal: true
      # == Schema Information
      #
      #  id     :bigint           not null, primary key
      #  amount :integer          not null
      def foo; end
    RUBY
  end

  it "passes two lines each carrying a rubocop or a brakeman marker" do
    expect_no_offenses(<<~RUBY)
      # rubocop:disable Metrics/AbcSize
      # brakeman:ignore SQL Injection covering the sanitized upstream input
      def foo; end
    RUBY
  end

  it "passes a YARDoc block with a summary line and two tag lines" do
    expect_no_offenses(<<~RUBY)
      # Retries a webhook.
      # @param payload [Hash]
      # @return [Boolean]
      def retry_webhook(payload); end
    RUBY
  end

  it "passes a YARDoc block of tag lines alone, with no summary line" do
    expect_no_offenses(<<~RUBY)
      # @param payload [Hash]
      # @return [Boolean]
      def retry_webhook(payload); end
    RUBY
  end

  it "passes a YARDoc @example tag with a multi-line indented body" do
    expect_no_offenses(<<~RUBY)
      # Retries a webhook.
      # @example
      #   retry_webhook(payload)
      #   retry_webhook(payload, force: true)
      def retry_webhook(payload); end
    RUBY
  end

  it "passes a bare # separator line placed between two tag lines" do
    expect_no_offenses(<<~RUBY)
      # @param payload [Hash]
      #
      # @return [Boolean]
      def retry_webhook(payload); end
    RUBY
  end

  it "passes a YARDoc block using the @abstract tag" do
    expect_no_offenses(<<~RUBY)
      # @abstract
      class ApplicationCommand; end
    RUBY
  end

  it "passes a summary line followed by an @attr_reader tag above a class definition" do
    expect_no_offenses(<<~RUBY)
      # Wraps a payment provider's refund object.
      # @attr_reader [String] status
      class Refund; end
    RUBY
  end

  it "passes an indented continuation line under an @param tag" do
    expect_no_offenses(<<~RUBY)
      # @param payload [Hash]
      #   a payload carrying the vendor's webhook signature and retry count
      def retry_webhook(payload); end
    RUBY
  end

  it "passes a single prose line naming an external constraint" do
    expect_no_offenses(<<~RUBY)
      # The vendor's webhook caps a retry at three attempts.
      def retry_webhook; end
    RUBY
  end

  it "passes a two-line prose run directly above a method definition" do
    expect_no_offenses(<<~RUBY)
      # The vendor's webhook caps a retry at three attempts before it fails.
      # A fourth attempt is rejected by the gateway itself, ahead of our code.
      def retry_webhook; end
    RUBY
  end

  it "reports a two-line prose run directly above a class definition" do
    line1 = "# The vendor's webhook caps a retry at three attempts before it fails."
    line2 = "# A fourth attempt is rejected by the gateway itself, ahead of our code."
    expect_offense(<<~RUBY)
      #{line1}
      #{"^" * line1.length} #{described_class::MSG}
      #{line2}
      class RetryPolicy; end
    RUBY
  end

  it "reports a three-line prose run directly above a method definition" do
    line1 = "# The vendor's webhook caps a retry at three attempts before it fails."
    expect_offense(<<~RUBY)
      #{line1}
      #{"^" * line1.length} #{described_class::MSG}
      # A fourth attempt is rejected by the gateway itself, ahead of our code.
      # The circuit breaker then opens for the remainder of the deploy window.
      def retry_webhook; end
    RUBY
  end

  it "passes a two-line summary followed by tag lines above a method definition" do
    expect_no_offenses(<<~RUBY)
      # The vendor's webhook caps a retry at three attempts before it fails.
      # A fourth attempt is rejected by the gateway itself, ahead of our code.
      # @param payload [Hash]
      # @return [Boolean]
      def retry_webhook(payload); end
    RUBY
  end

  it "reports a two-line summary followed by a tag line above a class definition" do
    line1 = "# The vendor's webhook caps a retry at three attempts before it fails."
    expect_offense(<<~RUBY)
      #{line1}
      #{"^" * line1.length} #{described_class::MSG}
      # A fourth attempt is rejected by the gateway itself, ahead of our code.
      # @param payload [Hash]
      class RetryPolicy
        def initialize(payload); end
      end
    RUBY
  end

  context "with MaxClassProseLines configured to 2" do
    let(:cop_config) { { "MaxClassProseLines" => 2 } }

    it "passes a two-line prose run directly above a class definition" do
      expect_no_offenses(<<~RUBY)
        # The vendor's webhook caps a retry at three attempts before it fails.
        # A fourth attempt is rejected by the gateway itself, ahead of our code.
        class RetryPolicy; end
      RUBY
    end
  end

  context "with MaxProseLines configured to 3" do
    let(:cop_config) { { "MaxProseLines" => 3 } }

    it "passes a three-line prose run directly above a method definition" do
      expect_no_offenses(<<~RUBY)
        # The vendor's webhook caps a retry at three attempts before it fails.
        # A fourth attempt is rejected by the gateway itself, ahead of our code.
        # The circuit breaker then opens for the remainder of the deploy window.
        def retry_webhook; end
      RUBY
    end
  end

  it "pins that a =begin and =end block comment never forms a comment run" do
    expect_no_offenses(<<~RUBY)
      =begin
      This spans several lines of block comment prose that would exceed
      any ordinary prose budget if it were treated as a comment run.
      =end
      def foo; end
    RUBY
  end

  it "does not merge a trailing comment on a code line into a one-line summary above a class definition" do
    expect_no_offenses(<<~RUBY)
      x = 1 # a rationale trailing on the code line, long enough to matter
      # Summary.
      class Foo; end
    RUBY
  end

  it "reports a run mixing a frozen_string_literal directive with prose lines" do
    line = "# frozen_string_literal: true"
    expect_offense(<<~RUBY)
      #{line}
      #{"^" * line.length} #{described_class::MSG}
      # This also explains why the retry path re-verifies the payload here.
      # It stays this way because the vendor's webhook signs each retry once.
    RUBY
  end

  it "passes three lines each carrying a reek marker" do
    expect_no_offenses(<<~RUBY)
      # reek:TooManyMethods
      # reek:FeatureEnvy { enabled: false }
      # reek:UtilityFunction
      def foo; end
    RUBY
  end

  it "reports a two-line prose run directly above a module definition" do
    line1 = "# The vendor's webhook caps a retry at three attempts before it fails."
    expect_offense(<<~RUBY)
      #{line1}
      #{"^" * line1.length} #{described_class::MSG}
      # A fourth attempt is rejected by the gateway itself, ahead of our code.
      module Refunds; end
    RUBY
  end

  it "reports a two-line prose run directly above a `class << self` reopening" do
    line1 = "# The vendor's webhook caps a retry at three attempts before it fails."
    expect_offense(<<~RUBY)
      #{line1}
      #{"^" * line1.length} #{described_class::MSG}
      # A fourth attempt is rejected by the gateway itself, ahead of our code.
      class << self
      end
    RUBY
  end

  it "reports a prose line followed by a schema information block" do
    line1 = "# Tracks who requested each refund and why."
    expect_offense(<<~RUBY)
      #{line1}
      #{"^" * line1.length} #{described_class::MSG}
      # == Schema Information
      #
      #  id     :bigint           not null, primary key
      #  amount :integer          not null
      class Refund; end
    RUBY
  end
end
