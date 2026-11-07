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

  # Walks a popover's real widget tree (GTK builds a GtkPopoverMenu's rows
  # itself from the Gio::MenuModel, as private GtkModelButton/Gtk::Label
  # pairs with no public lookup-by-action API) to find the row whose label is
  # `text`, then activates it the way a pointer click would — so flipping the
  # guitar over and emptying the chord from the menu goes through the actual
  # popover and item a person clicks, not straight through the action.
  def click_menu_item(popover, text)
    find = lambda do |widget|
      if widget.nil?
        next nil
      end

      if widget.respond_to?(:label) && (widget.label.to_s == text)
        next widget.parent
      end

      child = widget.first_child
      until child.nil?
        found = find.call(child)
        unless found.nil?
          break found
        end

        child = child.next_sibling
      end
    end

    find.call(popover).activate
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

  d.step("clicking the bookmarked chord's preview goes back to the chord view") do
    window.call.bookmarks_container.first_child.child.signal_emit("clicked")
  end

  d.step("the chord view shows the chord that preview button carried") do
    d.check("back on the chord view") { window.call.navigation_stack.visible_page.tag == "chord-view" }
    d.check("diagram shows the bookmarked chord") { window.call.diagram.chord == C }
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

  d.step("opening the primary menu and flipping the guitar over") do
    window.call.menu_button.popup
    click_menu_item(window.call.menu_button.popover, "Left-handed")
  end

  d.step("the diagram is left-handed") do
    d.check("diagram knows") { window.call.diagram.guitar_type == :left_handed }
    d.check("the setting was written") { window.call.settings.handedness == "left-handed" }
    d.shot("09-left-handed")
  end

  d.step("clicking the barre spin's buttons all the way up clamps at 12") do
    spin = window.call.diagram.barre_spin
    13.times { spin.increment_button.signal_emit("clicked") }
  end

  d.step("the barre spin clamped at its max") do
    d.check("value clamped to 12") { window.call.diagram.barre_spin.value == 12 }
    d.check("increment is now insensitive") { !window.call.diagram.barre_spin.increment_button.sensitive? }
    d.check("decrement is sensitive") { window.call.diagram.barre_spin.decrement_button.sensitive? }
  end

  d.step("clicking the barre spin's buttons all the way down clamps at 1") do
    spin = window.call.diagram.barre_spin
    13.times { spin.decrement_button.signal_emit("clicked") }
  end

  d.step("the barre spin clamped at its min") do
    d.check("value clamped to 1") { window.call.diagram.barre_spin.value == 1 }
    d.check("decrement is now insensitive") { !window.call.diagram.barre_spin.decrement_button.sensitive? }
    d.check("increment is sensitive") { window.call.diagram.barre_spin.increment_button.sensitive? }
  end

  d.step("opening the shortcuts dialog") do
    application.shortcuts_dialog.present(window.call.window)
  end

  d.step("the shortcuts dialog is up") do
    d.check("dialog exists") { !application.shortcuts_dialog.build.nil? }
    d.check("all 9 items are there") { application.shortcuts_dialog.items.length == 9 }
    d.check("item text matches SECTIONS") do
      expected = Fretboard::ShortcutsDialog::SECTIONS.flat_map { |s| s[:items].map { |title, _| title } }
      application.shortcuts_dialog.items.map(&:title) == expected
    end
    d.shot("10-shortcuts", application.shortcuts_dialog.build)
  end

  d.step("opening the about dialog") do
    window.call.about_dialog.present(window.call.window)
  end

  d.step("the about dialog is up") do
    d.check("version is set") { window.call.about_dialog.root.version == "9.1" }
    d.shot("11-about", window.call.about_dialog.build)
  end

  d.step("closing the open dialogs and resizing the window") do
    # A still-presented Adw dialog intercepts the main window's
    # "close-request" entirely (it owns the back/escape gesture while open),
    # so both dialogs opened earlier in this run have to actually close
    # first, or the window's own close-request handler never runs at all.
    window.call.about_dialog.build.close
    application.shortcuts_dialog.build.close
    window.call.window.set_default_size(777, 410)
  end

  d.step("closing the window persists its size and the current chord") do
    # One tick after set_default_size, the window has already settled on the
    # size it will actually report (GTK overrides width back toward the
    # content's natural size once realized; height is free to grow), so that
    # settled size — not the one asked for — is what remember() has to save.
    expected_size = window.call.window.default_size
    chord_at_close = window.call.diagram.chord.dup

    window.call.window.signal_emit("close-request")

    d.check("window width was saved") { Fretboard::Settings.new.window_width == expected_size[0] }
    d.check("window height was saved") { Fretboard::Settings.new.window_height == expected_size[1] }
    d.check("the saved height is the one asked for") { Fretboard::Settings.new.window_height == 410 }
    d.check("the current chord was saved") { Fretboard::Bookmarks.load_current_chord.chord == chord_at_close }
  end
end
