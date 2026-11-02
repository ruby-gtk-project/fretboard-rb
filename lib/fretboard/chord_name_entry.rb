# frozen_string_literal: true

require "adwaita"
require_relative "chord_ops"

module Fretboard
  # ChordNameEntry is the chord name field under the diagram, with the overlay
  # button at its right edge: a confirm button while the text differs from the
  # chord on show, and the enharmonic equivalent of the name once it matches.
  #
  # Ported from upstream's src/widgets/chord_name_entry.blp and
  # src/widgets/chord_name_entry.rs. Upstream's "enharmonic-clicked" signal is
  # the on_enharmonic_clicked callback, and the entry's own "activate" is
  # forwarded to on_activate once the typed name has been prettified.
  class ChordNameEntry
    def initialize(on_activate: nil, on_enharmonic_clicked: nil)
      @on_activate = on_activate
      @on_enharmonic_clicked = on_enharmonic_clicked
      @buffer = ""
      @has_enharmonic_equivalent = false
      @programmatically_changed = false
    end

    def build
      root.tap do |box|
        box.append(overlay)

        overlay.tap do |over|
          over.child = entry
          over.add_overlay(revealer)

          revealer.tap do |reveal|
            reveal.child = stack

            stack.tap do |pages|
              pages.add_named(confirm_button, "confirm-button")
              pages.add_named(enharmonic_button, "enharmonic-equivalent")
            end
          end
        end

        entry.tap do |field|
          field.signal_connect("changed") { on_changed }
          field.signal_connect("activate") { on_entry_activated }
        end

        confirm_button.signal_connect("clicked") { entry.signal_emit("activate") }
        enharmonic_button.signal_connect("clicked") { on_enharmonic_clicked }
      end
    end

    # The chord name as the database and the bookmarks store it.
    def serialized_buffer_text = ChordOps.serialize_chord_name(@buffer)

    # Replaces the text with a name the app worked out, rather than one the
    # user typed, and works out whether that name has another spelling.
    def overwrite_text(text)
      ChordOps.prettify_chord_name(text).then do |prettified|
        @buffer = prettified
        calculate_enharmonic_equivalent(prettified)
        entry.text = prettified
      end
    end

    # Puts the other spelling of the name on the overlay button, or hides the
    # button when the name has no other spelling.
    def calculate_enharmonic_equivalent(chord_name)
      ChordOps.enharmonic_equivalent(ChordOps.serialize_chord_name(chord_name)).then do |equivalent|
        if equivalent.nil?
          hide_revealer
          @has_enharmonic_equivalent = false
        else
          show_enharmonic(ChordOps.prettify_chord_name(equivalent))
          @has_enharmonic_equivalent = true
        end
      end
    end

    def entry
      @entry ||= Gtk::Entry.new.tap do |field|
        field.xalign = 0.5
        field.hexpand = true
        # translators: keep this short! use only 'chord' or 'name' instead of
        # both if necessary.
        field.placeholder_text = "Chord Name"
        field.tooltip_text = "Chord Name"
      end
    end

    def confirm_button
      @confirm_button ||= overlay_button.tap do |button|
        button.icon_name = "checkmark-large-symbolic"
        button.tooltip_text = "Confirm"
      end
    end

    def enharmonic_button
      @enharmonic_button ||= overlay_button.tap do |button|
        button.tooltip_text = "Enharmonic Equivalent"
      end
    end

    def stack
      @stack ||= Gtk::Stack.new.tap do |pages|
        pages.transition_type = :crossfade
        pages.transition_duration = 200
      end
    end

    def revealer
      @revealer ||= Gtk::Revealer.new.tap do |reveal|
        reveal.transition_type = :crossfade
        reveal.transition_duration = 200
        reveal.halign = :end
        reveal.margin_top = 6
        reveal.margin_bottom = 6
        reveal.margin_end = 6
      end
    end

    def overlay
      @overlay ||= Gtk::Overlay.new.tap do |over|
        over.hexpand = true
      end
    end

    # Upstream's template root is a plain widget with a bin layout, whose
    # child fills it; a box needs to be told to let the entry expand.
    def root
      @root ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.hexpand = true
        box.add_css_class("fretboard-chord-name-entry")
      end
    end

    private

      def overlay_button
        Gtk::Button.new.tap do |button|
          button.halign = :end
          button.add_css_class("flat")
          button.add_css_class("dimmed")
        end
      end

      def on_changed
        if @programmatically_changed
          @programmatically_changed = false
        else
          refresh_revealer
        end
      end

      def refresh_revealer
        entry.text.then do |text|
          if text != @buffer && !text.empty?
            stack.visible_child_name = "confirm-button"
            show_revealer
          elsif @has_enharmonic_equivalent && !text.empty?
            show_revealer
          else
            hide_revealer
          end
        end
      end

      # The entry's own handling of activation: the typed name is prettified in
      # place, and only then does the window get to look it up.
      def on_entry_activated
        @programmatically_changed = true
        overwrite_text(entry.text)
        entry.position = -1
        @on_activate&.call
      end

      def on_enharmonic_clicked
        "#{enharmonic_button.label}#{entry.text.each_char.drop(2).join}".then do |modified_name|
          @programmatically_changed = true
          overwrite_text(modified_name)
          @on_enharmonic_clicked&.call
        end
      end

      def show_enharmonic(equivalent)
        enharmonic_button.label = equivalent
        show_revealer
        stack.visible_child_name = "enharmonic-equivalent"
      end

      def show_revealer
        revealer.visible = true
        revealer.reveal_child = true
      end

      def hide_revealer
        revealer.visible = false
        revealer.reveal_child = false
      end
  end
end
