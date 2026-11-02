# frozen_string_literal: true

require "json"
require "fileutils"

module Fretboard
  # Settings holds the same keys as upstream's dev.bragefuglseth.Fretboard
  # GSettings schema (data/dev.bragefuglseth.Fretboard.gschema.xml).
  #
  # Upstream uses GSettings, which needs a compiled schema installed into the
  # system's glib-2.0/schemas directory. Requiring an install step to run the
  # app from a checkout is worse than the alternative, so the same keys,
  # defaults and semantics are backed by a small JSON file under
  # XDG_CONFIG_HOME instead.
  class Settings
    DEFAULTS = {
      "window-width"  => 550,
      "window-height" => 650,
      "is-maximized"  => false,
      "handedness"    => "right-handed",
    }.freeze

    # The two values the handedness key is allowed to take.
    HANDEDNESS = %w[right-handed left-handed].freeze

    def initialize(path: nil)
      @path = path || default_path
      @values = DEFAULTS.merge(read)
    end

    def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

    def []=(key, value)
      @values[key.to_s] = value
      write
      value
    end

    def location = @path

    DEFAULTS.each_key do |key|
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
      @values["is-maximized"] = window.maximized?

      unless window.maximized?
        @values["window-width"] = window.default_size[0]
        @values["window-height"] = window.default_size[1]
      end

      write
    end

    private

      def default_path
        File.join(
          ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config")),
          "fretboard-rb",
          "settings.json",
        )
      end

      def read
        if File.exist?(@path)
          parse(File.read(@path))
        else
          {}
        end
      end

      def parse(contents)
        JSON.parse(contents)
      rescue JSON::ParserError => error
        warn("Error parsing #{@path}: #{error.message}")
        {}
      end

      def write
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.pretty_generate(@values))
      end
  end
end
