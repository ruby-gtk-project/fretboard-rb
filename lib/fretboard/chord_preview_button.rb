# frozen_string_literal: true

require "adwaita"
require_relative "chord_ops"
require_relative "chord_preview"

module Fretboard
  # ChordPreviewButton is one cell of the variants or bookmarks page: a flat
  # button wrapping a read-only chord diagram, inside a flow box child.
  #
  # Ported from the loops in upstream's src/widgets/window.rs that fill the
  # variants and bookmarks containers (more_variants and show_bookmarks). The
  # bookmarks page puts the chord's name under the diagram, which is what
  # `show_name` does here.
  #
  # The button is already focusable, so the flow box child is not: upstream
  # avoids that unnecessary layer of indirection too.
  class ChordPreviewButton
    def initialize(chord:, name:, guitar_type:, show_name: false, &on_clicked)
      @chord = chord
      @name = name
      @guitar_type = guitar_type
      @show_name = show_name
      @on_clicked = on_clicked
    end

    def build
      root.tap do |child|
        child.child = button

        button.tap do |pressable|
          pressable.child = content
          pressable.signal_connect("clicked") { @on_clicked&.call(@chord, @name) }
        end
      end
    end

    def preview
      @preview ||= ChordPreview.new(
        chord:       @chord,
        guitar_type: @guitar_type,
        chord_name:  @name,
      )
    end

    def name_label
      @name_label ||= Gtk::Label.new(ChordOps.prettify_chord_name(@name)).tap do |label|
        label.justify = :center
        label.add_css_class("title-3")
      end
    end

    def button
      @button ||= Gtk::Button.new.tap do |pressable|
        pressable.add_css_class("flat")
        pressable.add_css_class("fretboard-chord-preview-button")
        pressable.hexpand = false

        if @show_name
          pressable.halign = :fill
        else
          pressable.halign = :center
        end
      end
    end

    def named_box
      @named_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.append(preview.build)
        box.append(name_label)
      end
    end

    def root
      @root ||= Gtk::FlowBoxChild.new.tap do |child|
        child.focusable = false
        child.add_css_class("no-hover-active")
      end
    end

    private

      def content
        if @show_name
          named_box
        else
          preview.build
        end
      end
  end
end
