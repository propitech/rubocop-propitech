# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"

RSpec.describe RuboCop::Cop::Propitech::AuditTagOnExampleGroup, :config do
  let(:cop_config) { { "Tags" => %w[audit_on_pr] } }

  def message(tag = "audit_on_pr")
    format(described_class::MSG, tag: tag)
  end

  it "flags the tag on RSpec.describe" do
    expect_offense(<<~RUBY)
      RSpec.describe "Inviting a teacher", :audit_on_pr, type: :system do
                                           ^^^^^^^^^^^^ #{message}
      end
    RUBY
  end

  it "flags the tag on a bare describe, context and feature" do
    expect_offense(<<~RUBY)
      describe "Members", :audit_on_pr do
                          ^^^^^^^^^^^^ #{message}
        context "as admin", :audit_on_pr do
                            ^^^^^^^^^^^^ #{message}
        end
      end
      feature "Invite", :audit_on_pr do
                        ^^^^^^^^^^^^ #{message}
      end
    RUBY
  end

  it "flags the tag written as a metadata pair" do
    expect_offense(<<~RUBY)
      RSpec.describe "Members", audit_on_pr: true do
                                ^^^^^^^^^^^^^^^^^ #{message}
      end
    RUBY
  end

  it "passes the tag on an example" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe "Inviting a teacher", type: :system do
        it "sends the invitation", :audit_on_pr do
        end

        specify "shows the list", :audit_on_pr do
        end
      end
    RUBY
  end

  it "passes a group with another tag" do
    expect_no_offenses(<<~RUBY)
      RSpec.describe "Members", :js, type: :system do
      end
    RUBY
  end

  context "with another tag" do
    let(:cop_config) { { "Tags" => %w[a11y] } }

    it "respects the configured tag" do
      expect_offense(<<~RUBY)
        context "Members", :a11y do
                           ^^^^^ #{message("a11y")}
        end
      RUBY
    end

    it "passes the tag the default list would have named" do
      expect_no_offenses(<<~RUBY)
        context "Members", :audit_on_pr do
        end
      RUBY
    end
  end

  context "with no configuration" do
    let(:cop_config) { {} }

    it "flags nothing" do
      expect_no_offenses(<<~RUBY)
        RSpec.describe "Members", :audit_on_pr do
        end
      RUBY
    end
  end

  it "ships disabled" do
    default = YAML.load_file(File.expand_path("../../../../config/default.yml", __dir__))
    expect(default.fetch("Propitech/AuditTagOnExampleGroup")).to include("Enabled" => false)
  end
end
