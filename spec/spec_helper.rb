# frozen_string_literal: true

# Config for development dependencies of this library
# i.e., not configured by this library
#
# SimpleCov & related config (must run BEFORE any other requires)
# NOTE: Gemfiles for non-coverage appraisals may not have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  if Kettle::Soup::Cover::DO_COV
    # Requiring simplecov loads the project-local `.simplecov`.
    require "simplecov"
    require "kettle/soup/cover/config"
    SimpleCov.start
  end
rescue LoadError => error
  # check the error message and re-raise when unexpected
  raise error unless error.message.include?("kettle")
end

# External RSpec & related config
#
# kettle-test is a gemspec development dependency, but this fork's Nix
# devshell (flake.nix) only vendors the app's runtime gems plus bare
# `rspec` as a system package — kettle-test, kettle-dev and rspec-core's
# own gem (as opposed to the nixpkgs-packaged rspec meta-gem) are not on
# the load path there. Requiring "rspec/core" still works (nixpkgs ships
# it), so the fallback below configures plain RSpec instead of failing the
# whole suite before a single example loads. See spec/README.md.
begin
  require "kettle/test/rspec"
  # `kettle/test/rspec` installs harness helpers documented in spec/README.md.
rescue LoadError => error
  raise error unless error.message.include?("kettle")

  warn "[spec_helper] kettle-test is not available; falling back to plain RSpec (see spec/README.md)"
  require "rspec/core"
end

# This library
require "fretboard/rb"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
