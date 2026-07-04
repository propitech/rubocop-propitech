# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"

RSpec.describe RuboCop::Cop::Propitech::NoViewAssembly, :config do
  it "flags instantiating a non-component, non-form object" do
    expect_offense(<<~RUBY)
      SpaceLabel.new(space)
                 ^^^ #{format(described_class::MSG_NEW, const: "SpaceLabel")}
    RUBY
  end

  it "allows a ViewComponent render target" do
    expect_no_offenses("render App::Card::Component.new(row: row)")
  end

  it "allows a simple_form backing object" do
    expect_no_offenses("simple_form_for Forms::Owner::RateForm.new")
  end

  it "flags an ActiveRecord query" do
    expect_offense(<<~RUBY)
      Taxon.kind_amenity.order(:name)
                         ^^^^^ #{format(described_class::MSG_QUERY, method: "order")}
    RUBY
  end

  it "flags a lambda captured in a local" do
    expect_offense(<<~RUBY)
      step = ->(on) { path(on) }
             ^^^^^^^^^^^^^^^^^^^ #{described_class::MSG_LAMBDA}
    RUBY
  end

  it "allows an inline callback lambda passed as an argument" do
    expect_no_offenses("f.input :x, collection: xs, label_method: ->(o) { label(o) }")
  end

  it "allows a plain local naming a translated string" do
    expect_no_offenses('confirm = t(".remove")')
  end

  it "allows a helper call standing in for the instantiation" do
    expect_no_offenses("space_label(space)")
  end
end
