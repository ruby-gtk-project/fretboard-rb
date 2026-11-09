require_relative "rb/version"

# frozen_string_literal: true

# The gem's conventional entry point, named after the RubyGems package
# ("fretboard-rb" dasherizes to this path). It exists only so that
# `require "fretboard/rb"` — the form spec/spec_helper.rb and kettle-jem's
# generated tooling use to load the version constant without pulling in the
# full GTK4/Libadwaita application (lib/fretboard.rb) — resolves to
# something. The app itself is loaded with `require "fretboard"`, from
# exe/fretboard and lib/fretboard.rb.
