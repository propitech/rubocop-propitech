# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"

RSpec.describe RuboCop::Cop::Propitech::StyleReadInSystemSpec, :config do
  let(:cop_config) { { "Include" => ["spec/system/**/*"] } }

  def script_message(read)
    format(described_class::MSG_SCRIPT, read: read)
  end

  def native_message(read)
    format(described_class::MSG_NATIVE, read: read)
  end

  it "flags a getComputedStyle read in evaluate_script" do
    expect_offense(<<~RUBY, "spec/system/components/schedule/grid_spec.rb")
      display = page.evaluate_script("getComputedStyle(document.querySelector('.grid')).display")
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{script_message("getComputedStyle")}
    RUBY
  end

  it "flags a getBoundingClientRect read in execute_script and evaluate_async_script" do
    expect_offense(<<~RUBY, "spec/system/components/schedule/grid_spec.rb")
      page.execute_script("return el.getBoundingClientRect().width")
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{script_message("getBoundingClientRect")}
      page.evaluate_async_script("el.getBoundingClientRect()", 1)
                                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{script_message("getBoundingClientRect")}
    RUBY
  end

  it "flags a read inside an interpolated script" do
    expect_offense(<<~'RUBY', "spec/system/a_spec.rb")
      page.evaluate_script("getComputedStyle(#{selector}).color")
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not read a computed style or a box (`getComputedStyle`) in a system spec: pin it in the component or view spec. A read for an accessibility requirement stays with a `rubocop:disable` comment that gives the reason.
    RUBY
  end

  it "flags a read given to an endless-def helper that interpolates its argument", :ruby34 do
    expect_offense(<<~'RUBY', "spec/system/a_spec.rb")
      def measure(script) = page.evaluate_script("(() => { #{script} })()")

      measure("return document.querySelector('button').getBoundingClientRect().height")
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not read a computed style or a box (`getBoundingClientRect`) in a system spec: pin it in the component or view spec. A read for an accessibility requirement stays with a `rubocop:disable` comment that gives the reason.
    RUBY
  end

  it "flags a read given to a helper defined after the call, with a normal def and execute_script" do
    expect_offense(<<~'RUBY', "spec/system/a_spec.rb")
      run("getComputedStyle(el).display")
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not read a computed style or a box (`getComputedStyle`) in a system spec: pin it in the component or view spec. A read for an accessibility requirement stays with a `rubocop:disable` comment that gives the reason.

      def run(code)
        page.execute_script("return (function () { #{code} })()")
      end
    RUBY
  end

  it "flags a read given as a keyword argument to a helper", :ruby34 do
    expect_offense(<<~'RUBY', "spec/system/a_spec.rb")
      def kw(script:) = page.evaluate_script("(() => { #{script} })()")

      kw(script: "getComputedStyle(el).color")
                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not read a computed style or a box (`getComputedStyle`) in a system spec: pin it in the component or view spec. A read for an accessibility requirement stays with a `rubocop:disable` comment that gives the reason.
    RUBY
  end

  it "reads a helper with a destructured parameter without error and follows it" do
    expect_offense(<<~'RUBY', "spec/system/a_spec.rb")
      def size_of((width, height), script)
        page.evaluate_script("#{width} #{height} #{script}")
      end

      size_of([1, 2], "el.getBoundingClientRect()")
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not read a computed style or a box (`getBoundingClientRect`) in a system spec: pin it in the component or view spec. A read for an accessibility requirement stays with a `rubocop:disable` comment that gives the reason.
    RUBY
  end

  it "does not follow a constant defined in another file" do
    expect_no_offenses(<<~RUBY, "spec/system/a_spec.rb")
      page.evaluate_script(MemberCardProbe::LINK)
    RUBY
  end

  it "passes a helper call that reads no style", :ruby34 do
    expect_no_offenses(<<~'RUBY', "spec/system/a_spec.rb")
      def measure(script) = page.evaluate_script("(() => { #{script} })()")

      measure("return document.title")
    RUBY
  end

  it "passes a call to a method that does not interpolate its argument into a script", :ruby34 do
    expect_no_offenses(<<~RUBY, "spec/system/a_spec.rb")
      def label(text) = page.evaluate_script("document.title")
      def other(text) = text.upcase

      label("getComputedStyle")
      other("getComputedStyle")
    RUBY
  end

  it "flags native.size and native.location" do
    expect_offense(<<~RUBY, "spec/system/a_spec.rb")
      find("button").native.size
      ^^^^^^^^^^^^^^^^^^^^^^^^^^ #{native_message("native.size")}
      find("button").native.location
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{native_message("native.location")}
    RUBY
  end

  it "flags a read inside a heredoc script" do
    expect_offense(<<~RUBY, "spec/system/a_spec.rb")
      page.evaluate_script(<<~JS)
                           ^^^^^ Do not read a computed style or a box (`getBoundingClientRect`) in a system spec: pin it in the component or view spec. A read for an accessibility requirement stays with a `rubocop:disable` comment that gives the reason.
        const el = document.querySelector("button")
        return el.getBoundingClientRect().height
      JS
    RUBY
  end

  it "passes a heredoc script that reads no style" do
    expect_no_offenses(<<~RUBY, "spec/system/a_spec.rb")
      page.evaluate_script(<<~JS)
        return document.title
      JS
    RUBY
  end

  it "flags native.size through safe navigation" do
    expect_offense(<<~RUBY, "spec/system/a_spec.rb")
      find("button")&.native&.size
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{native_message("native.size")}
    RUBY
  end

  it "passes a script that reads no style" do
    expect_no_offenses(<<~RUBY, "spec/system/a_spec.rb")
      page.evaluate_script("document.title")
      page.execute_script("window.scrollTo(0, 0)")
      element.size
      element.native.text
    RUBY
  end

  it "passes a read outside the system-spec paths" do
    cop_config["Include"] = ["spec/system/**/*"]
    expect_no_offenses(<<~RUBY, "spec/components/grid_spec.rb")
      page.evaluate_script("getComputedStyle(el).display")
    RUBY
  end

  it "is silenced by a rubocop:disable comment that carries the reason" do
    expect_no_offenses(<<~RUBY, "spec/system/a_spec.rb")
      # rubocop:disable Propitech/StyleReadInSystemSpec -- 44 px hit target (accessibility)
      height = page.evaluate_script("document.querySelector('button').getBoundingClientRect().height")
      # rubocop:enable Propitech/StyleReadInSystemSpec
    RUBY
  end

  it "is silenced by a trailing rubocop:disable comment" do
    expect_no_offenses(<<~RUBY, "spec/system/a_spec.rb")
      find("a").native.size # rubocop:disable Propitech/StyleReadInSystemSpec -- focus ring
    RUBY
  end

  it "ships disabled, at warning severity, scoped to the system specs" do
    default = YAML.load_file(File.expand_path("../../../../config/default.yml", __dir__))
    expect(default.fetch("Propitech/StyleReadInSystemSpec"))
      .to include("Enabled" => false, "Severity" => "warning", "Include" => ["spec/system/**/*"])
  end
end
