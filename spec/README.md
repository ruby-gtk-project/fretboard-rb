# Specs

This project uses `kettle-test` as its RSpec harness. The generated
`spec/spec_helper.rb` requires `kettle/test/rspec`, which installs the shared
test configuration and helper APIs used throughout the suite.

## Running without kettle-test

`kettle-test` is a gemspec development dependency, declared for `bundle
install` at the repo root. It is **not** vendored into this fork's Nix
devshell: `flake.nix`'s `devShells.default` only carries the app's runtime
gems (`nix/Gemfile` — `adwaita`, `gtk4`) plus a bare `rspec` from nixpkgs for
running the suite, so `kettle/test/rspec`, `kettle-dev` and rspec-core's own
gem are missing there.

`spec/spec_helper.rb` handles this: it tries `require "kettle/test/rspec"`
first and falls back to plain `require "rspec/core"` with a warning on
`LoadError`. Inside the Nix devshell, specs therefore run under plain RSpec
and the harness helpers below are **not** available — they only load when
`bundle exec rspec` runs against the root `Gemfile`'s full development
bundle, where `kettle-test` is actually installed.

## Harness Helpers

These helpers are available in specs after `spec/spec_helper.rb` loads:

- `stub_env("NAME" => "value")` temporarily sets environment variables and
  restores them after the example.
- `hide_env("NAME")` temporarily removes environment variables and restores
  them after the example.
- `block_is_expected` supports expectation syntax for blocks.
- `:check_output` disables default stream silencing for examples that need to
  assert output.
- `:freeze` and `:travel` metadata integrate with Timecop for example-level
  time control.
- `:skip_global_travel` opts an example out of global time travel.
- `pending_for` marks examples pending for selected runtimes or dependency
  versions.
- `include_context "with rake", "task_name"` is available when `rake` was
  loaded before `kettle/test/rspec`.

Prefer these helpers over ad hoc ENV mutation, direct Timecop setup, or direct
stdout/stderr plumbing. They keep specs isolated across parallel workers and
make local runs match CI behavior.
