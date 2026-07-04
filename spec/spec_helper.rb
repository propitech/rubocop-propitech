# frozen_string_literal: true

require "rubocop"
require "rubocop-propitech"
require "rubocop/rspec/support"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
