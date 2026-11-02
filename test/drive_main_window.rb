# frozen_string_literal: true

# Drives the main window: looks up a chord by name, plots one on the neck,
# bookmarks it, walks the variants and bookmarks pages, flips the guitar over
# and opens both dialogs.
#
#   nix develop --command xvfb-run -a ruby test/drive_main_window.rb

require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("fretboard-config")
ENV["XDG_DATA_HOME"] = Dir.mktmpdir("fretboard-data")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "fretboard"
require_relative "gtk_driver"

AM = [nil, 0, 2, 2, 1, 0].freeze
C = [nil, 3, 2, 0, 1, 0].freeze

app = Fretboard::Application.new

GtkDriver.drive(app, shots: "tmp/shots") do |d, application|
  window = -> { application.window }

  d.window { window.call.window }

  def act(window, name, parameter = nil)
    window.window.lookup_action(name).activate(parameter)
  end

  d.step("the window opens on the chord view") do
    d.check("title is Fretboard") { window.call.window.title == "Fretboard" }
    d.check("chord view is showing") { window.call.navigation_stack.visible_page.tag == "chord-view" }
    d.check("the stored chord is C") { window.call.diagram.chord == C }
    d.check("the entry says C") { window.call.entry.entry.text == "C" }
    d.check("chord actions are showing") { window.call.feedback_stack.visible_child_name == "chord-actions" }
    d.shot("01-chord-view")
  end

  d.step("typing a name and confirming it loads the chord") do
    window.call.entry.entry.text = "am"
    window.call.entry.entry.signal_emit("activate")
  end

  d.step("the diagram shows A minor") do
    d.check("entry prettified to Am") { window.call.entry.entry.text == "Am" }
    d.check("diagram shows Am") { window.call.diagram.chord == AM }
    d.check("neck position is 1") { window.call.diagram.neck_position == 1 }
    d.check("string heads follow the chord") { window.call.diagram.top_toggles[0].state == :muted }
    d.check("open strings are open") { window.call.diagram.top_toggles[1].state == :open }
    d.shot("02-am")
  end

  d.step("an unknown name reports that the chord was not found") do
    window.call.entry.entry.text = "zz"
    window.call.entry.entry.signal_emit("activate")
  end

  d.step("the feedback label is showing") do
    d.check("feedback shows the label") { window.call.feedback_stack.visible_child_name == "label" }
    d.check("the diagram is empty") { window.call.diagram.chord.compact.empty? }
    d.shot("03-not-found")
  end

  d.step("clicking the neck names the chord it makes") do
    act(window.call, "empty-chord")
    window.call.diagram.chord = AM.dup
    # A click, not `active = true`: the diagram listens for "clicked", so a
    # programmatic state change is deliberately not a user edit.
    window.call.diagram.toggle(2, 1).button.signal_emit("clicked")
  end

  d.step("the name follows the neck") do
    d.check("the entry was filled in") { window.call.entry.entry.text == "Am" }
    d.check("chord actions are showing") { window.call.feedback_stack.visible_child_name == "chord-actions" }
    d.shot("04-plotted")
  end

  d.step("emptying the chord clears everything") do
    act(window.call, "empty-chord")
  end

  d.step("the chord view is empty") do
    d.check("chord is empty") { window.call.diagram.chord.compact.empty? }
    d.check("entry is empty") { window.call.entry.entry.text.empty? }
    d.check("feedback is empty") { window.call.feedback_stack.visible_child_name == "empty" }
    d.shot("05-empty")
  end

  d.step("bookmarking the C chord") do
    window.call.entry.overwrite_text("C")
    window.call.diagram.chord = C.dup
    act(window.call, "bookmark-chord")
  end

  d.step("the bookmark was saved") do
    d.check("one bookmark") { window.call.bookmarks.to_a.length == 1 }
    d.check("the star is lit") { window.call.star_toggle.active? }
    d.check("the star icon changed") { window.call.star_toggle.icon_name == "star-large-symbolic" }
    d.check("the bookmarks button works") { window.call.bookmarks_button.sensitive? }
    d.check("the bookmarks file exists") { File.exist?(Fretboard::Bookmarks.default_path) }
  end

  d.step("opening the bookmarks page") do
    act(window.call, "bookmarks")
  end

  d.step("the bookmarks page lists the chord") do
    d.check("bookmarks page is showing") { window.call.navigation_stack.visible_page.tag == "bookmarks" }
    d.check("one preview") { !window.call.bookmarks_container.first_child.nil? }
    d.shot("06-bookmarks")
  end

  d.step("going back and asking for variants") do
    window.call.navigation_stack.pop
  end

  d.step("the variants page fills in") do
    act(window.call, "more-variants")
  end

  d.step("the variants page lists the fingerings") do
    d.check("variants page is showing") { window.call.navigation_stack.visible_page.tag == "more-variants" }
    d.check("variants, not the empty state") { window.call.variants_stack.visible_child_name == "variants" }
    d.check("the page is titled C") { window.call.variants_page.title == "C" }
    d.check("previews were built") { !window.call.variants_container.first_child.nil? }
    d.shot("07-variants")
  end

  d.step("picking a variant goes back to the chord view") do
    window.call.variants_container.first_child.child.signal_emit("clicked")
  end

  d.step("the chord view is showing again") do
    d.check("back on the chord view") { window.call.navigation_stack.visible_page.tag == "chord-view" }
    d.shot("08-variant-picked")
  end

  d.step("flipping the guitar over") do
    act(window.call, "set-handedness", GLib::Variant.new("left-handed"))
  end

  d.step("the diagram is left-handed") do
    d.check("diagram knows") { window.call.diagram.guitar_type == :left_handed }
    d.check("the setting was written") { window.call.settings.handedness == "left-handed" }
    d.shot("09-left-handed")
  end

  d.step("opening the shortcuts dialog") do
    application.shortcuts_dialog.present(window.call.window)
  end

  d.step("the shortcuts dialog is up") do
    d.check("dialog exists") { !application.shortcuts_dialog.build.nil? }
    d.shot("10-shortcuts", application.shortcuts_dialog.build)
  end

  d.step("opening the about dialog") do
    window.call.about_dialog.present(window.call.window)
  end

  d.step("the about dialog is up") do
    d.check("version is set") { window.call.about_dialog.root.version == "9.1" }
    d.shot("11-about", window.call.about_dialog.build)
  end
end
