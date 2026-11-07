# frozen_string_literal: true

require "gio2"
require "fileutils"

module Fretboard
  # Settings wraps upstream's actual GSettings schema
  # (data/dev.bragefuglseth.Fretboard.gschema.xml), carried over byte for
  # byte rather than reimplemented as a side file.
  #
  # Ported from upstream's load_window_size / save_window_size in
  # src/widgets/window.rs plus the schema itself. A packaged Fretboard has its
  # schema compiled into the system's glib-2.0/schemas by its install step, so
  # GSettings finds it on the default search path; this port is run from a
  # checkout with no install step, so (see below) it compiles the schema
  # itself into a cache directory and points GSETTINGS_SCHEMA_DIR there.
  # Either way, the keys are read and written through real GSettings:
  # `gsettings get dev.bragefuglseth.Fretboard window-width` and dconf-editor
  # see the same values this class does, and the handedness key's
  # translatable description lives where upstream put it, in the schema
  # itself, not orphaned in a comment.
  class Settings
    SCHEMA_ID = APP_ID

    # The two values the handedness key is allowed to take.
    HANDEDNESS = %w[right-handed left-handed].freeze

    SCHEMA_SOURCE_DIR = File.expand_path("../../data", __dir__)
    SCHEMA_SOURCE = File.join(SCHEMA_SOURCE_DIR, "#{SCHEMA_ID}.gschema.xml")
    COMPILED_DIR = File.join(
      ENV.fetch("XDG_CACHE_HOME", File.expand_path("~/.cache")),
      "fretboard-rb",
      "glib-schemas",
    )
    COMPILED_PATH = File.join(COMPILED_DIR, "gschemas.compiled")

    # GLib caches the default GSettings schema source for the life of the
    # process the first time anything asks for it, so pointing
    # GSETTINGS_SCHEMA_DIR at a freshly compiled copy of the schema has to
    # happen here, at load time, before `Gio::Settings.new` (or anything
    # else) can trigger that caching with our schema still missing from it.
    # An already-set GSETTINGS_SCHEMA_DIR is left alone, on the assumption
    # that whatever set it already accounts for this schema.
    unless ENV["GSETTINGS_SCHEMA_DIR"]
      begin
        FileUtils.mkdir_p(COMPILED_DIR)

        if !File.exist?(COMPILED_PATH) || File.mtime(SCHEMA_SOURCE) > File.mtime(COMPILED_PATH)
          unless system("glib-compile-schemas", "--strict", "--targetdir=#{COMPILED_DIR}", SCHEMA_SOURCE_DIR)
            warn("glib-compile-schemas failed to compile #{SCHEMA_SOURCE}; GSettings will fall back to its default search path.")
          end
        end

        ENV["GSETTINGS_SCHEMA_DIR"] = COMPILED_DIR if File.exist?(COMPILED_PATH)
      rescue Errno::ENOENT
        warn("glib-compile-schemas is not on PATH; GSettings will fall back to its default search path.")
      end
    end

    def initialize
      @settings = Gio::Settings.new(SCHEMA_ID)
    end

    def [](key) = @settings[key.to_s]

    def []=(key, value)
      @settings[key.to_s] = value
      value
    end

    %w[window-width window-height is-maximized handedness].each do |key|
      define_method(key.tr("-", "_")) { self[key] }
      define_method(:"#{key.tr("-", "_")}=") { |value| self[key] = value }
    end

    # Restores the window geometry recorded by the previous run, which is what
    # upstream's load_window_size does.
    def apply_to(window)
      window.set_default_size(self["window-width"], self["window-height"])

      if self["is-maximized"]
        window.maximize
      end
    end

    # Records the window geometry, skipping the size while maximized so the
    # restored size is the one the user actually chose.
    def remember(window)
      self["is-maximized"] = window.maximized?

      unless window.maximized?
        self["window-width"] = window.default_size[0]
        self["window-height"] = window.default_size[1]
      end
    end
  end
end
