# frozen_string_literal: true

# Drives the app under a non-English locale and reads the translated strings
# back off the widgets. A catalogue can be perfect on paper while the app shows
# English — the language was never selected, the po/ directory was not found,
# the string was never marked — and this is the check that notices.
#
#   nix develop --command xvfb-run -a ruby test/drive_translations.rb
#
# The locale is set here rather than in the environment so the script proves
# the same thing however it is started. The catalogue is read the first time a
# marker is called, which is after this point.

require "tmpdir"

ENV["LANGUAGE"] = "de"
ENV["LC_ALL"] = "de_DE.UTF-8"
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("fretboard-config")
ENV["XDG_DATA_HOME"] = Dir.mktmpdir("fretboard-data")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "fretboard"
require_relative "gtk_driver"

app = Fretboard::Application.new

GtkDriver.drive(app, shots: "tmp/shots") do |d, application|
  window = -> { application.window }

  d.window { window.call.window }

  d.step("the catalogue in use is German") do
    d.check("the de catalogue was selected") { Fretboard::I18n.catalogue.language == "de" }
    d.check("it carries messages") { Fretboard::I18n.catalogue.messages.length > 40 }
    d.check("all 37 languages are available") do
      Fretboard::I18n::Catalogue.available_languages.length == 37
    end
  end

  d.step("the chord view is in German") do
    d.check("the menu button") { window.call.menu_button.tooltip_text == "Hauptmenü" }
    # Nothing is bookmarked yet, so the button carries its insensitive
    # tooltip, which is a message of its own.
    d.check("the bookmarks button") { window.call.bookmarks_button.tooltip_text == "Keine Lesezeichen" }
    d.check("the feedback label") { window.call.feedback_label.label == "Akkord nicht gefunden" }
    d.check("the entry placeholder") { window.call.entry.entry.placeholder_text == "Akkordname" }
    d.check("the neck position spinner") do
      window.call.diagram.barre_spin.decrement_button.tooltip_text == "Nach oben bewegen"
    end
    d.shot("01-de-chord-view")
  end

  d.step("the string heads name their notes in German") do
    window.call.diagram.top_toggles[1].button.signal_emit("clicked")
  end

  d.step("the tooltip is the translated one") do
    d.check("an open string says so") do
      window.call.diagram.top_toggles[1].button.tooltip_text == "Offen (A)"
    end
  end

  d.step("the variants page is in German") do
    window.call.no_variants_page.tap do |page|
      d.check("its title") { page.title == "Keine Varianten" }
      d.check("its description keeps the link") { page.description.include?("<a href=") }
      d.check("its description is translated") do
        page.description.include?("Es gibt keine Akkorde mit diesem Namen")
      end

      d.check("the link wraps the translated words") do
        page.description.include?(">melden Sie sich</a>")
      end
    end
  end

  d.step("opening the shortcuts dialog") do
    application.shortcuts_dialog.present(window.call.window)
  end

  d.step("the shortcuts dialog is in German") do
    d.check("its title") { application.shortcuts_dialog.root.title == "Tastenkürzel" }
    d.shot("02-de-shortcuts", application.shortcuts_dialog.build)
  end

  d.step("opening the about dialog") do
    window.call.about_dialog.present(window.call.window)
  end

  d.step("the about dialog is in German") do
    window.call.about_dialog.root.tap do |dialog|
      d.check("the summary") { dialog.comments.start_with?("Wie wurde dieser Akkord") }
      d.check("the translators are credited") { dialog.translator_credits != "translator-credits" }
    end
    d.shot("03-de-about", window.call.about_dialog.build)
  end
end
