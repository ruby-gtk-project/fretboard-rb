# frozen_string_literal: true

require "adwaita"

module Fretboard
  # Style installs the app's stylesheet and makes the app's icons and assets
  # findable.
  #
  # Ported from upstream's data/resources/style.css, which upstream ships in a
  # GResource bundle and loads through the application's resource base path.
  # This port has no GResource, so the stylesheet is loaded from the data
  # directory and the icon directory is added to the display's icon theme.
  class Style
    def initialize(display: nil)
      @display = display
    end

    # Loads the stylesheet and registers the icon search path. Call once the
    # display exists, which means after the application has been activated.
    def install
      display.then do |target|
        Gtk::StyleContext.add_provider_for_display(
          target,
          provider,
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )

        Gtk::IconTheme.get_for_display(target).add_search_path(Fretboard.icons_dir)
      end
    end

    def display = @display ||= Gdk::Display.default

    def provider
      @provider ||= Gtk::CssProvider.new.tap do |css|
        css.load_from_path(self.class.stylesheet_path)
      end
    end

    def self.stylesheet_path = File.join(Fretboard.data_dir, "style.css")
  end
end
