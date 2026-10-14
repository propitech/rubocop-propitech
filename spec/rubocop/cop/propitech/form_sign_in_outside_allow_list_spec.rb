# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"

RSpec.describe RuboCop::Cop::Propitech::FormSignInOutsideAllowList, :config do
  let(:cop_config) do
    {
      "Methods" => %w[sign_in_through_form],
      "AllowedPaths" => ["spec/system/users/**/*", "spec/system/claim_account_spec.rb"]
    }
  end

  def message(method = "sign_in_through_form")
    format(described_class::MSG, method: method)
  end

  it "flags the sign-in call in a file outside the allow-list" do
    expect_offense(<<~RUBY, "spec/system/schools/members_invite_teacher_spec.rb")
      RSpec.describe "Inviting a teacher", type: :system do
        before { sign_in_through_form(admin) }
                 ^^^^^^^^^^^^^^^^^^^^ #{message}
      end
    RUBY
  end

  it "flags a call with a receiver" do
    expect_offense(<<~RUBY, "spec/system/schools/members_invite_teacher_spec.rb")
      page.sign_in_through_form(admin)
           ^^^^^^^^^^^^^^^^^^^^ #{message}
    RUBY
  end

  it "passes the call in a file the allow-list names" do
    expect_no_offenses(<<~RUBY, "spec/system/claim_account_spec.rb")
      before { sign_in_through_form(user) }
    RUBY
  end

  it "passes the call in a file a glob of the allow-list matches" do
    expect_no_offenses(<<~RUBY, "spec/system/users/sessions_spec.rb")
      before { sign_in_through_form(user) }
    RUBY
  end

  it "passes a method that is not configured" do
    expect_no_offenses(<<~RUBY, "spec/system/schools/members_invite_teacher_spec.rb")
      before { sign_in(admin) }
    RUBY
  end

  context "with another method name" do
    let(:cop_config) { { "Methods" => %w[login_via_ui], "AllowedPaths" => [] } }

    it "respects the configured name" do
      expect_offense(<<~RUBY, "spec/system/a_spec.rb")
        login_via_ui(user)
        ^^^^^^^^^^^^ #{message("login_via_ui")}
      RUBY
    end

    it "passes the name the default list would have used" do
      expect_no_offenses(<<~RUBY, "spec/system/a_spec.rb")
        sign_in_through_form(user)
      RUBY
    end
  end

  context "with no configuration" do
    let(:cop_config) { {} }

    it "flags nothing" do
      expect_no_offenses(<<~RUBY, "spec/system/a_spec.rb")
        sign_in_through_form(user)
      RUBY
    end
  end

  it "ships disabled" do
    default = YAML.load_file(File.expand_path("../../../../config/default.yml", __dir__))
    expect(default.fetch("Propitech/FormSignInOutsideAllowList")).to include("Enabled" => false)
  end
end
