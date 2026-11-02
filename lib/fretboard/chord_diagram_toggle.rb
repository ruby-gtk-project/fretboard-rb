# frozen_string_literal: true

require "adwaita"

module Fretboard
  # ChordDiagramToggle is one cell of the guitar neck: the round button that
  # presses a string down on a fret.
  #
  # Ported from upstream's src/widgets/chord_diagram_toggle.blp and
  # src/widgets/chord_diagram_toggle.rs. Upstream is a GObject subclass with
  # the CSS name "chord-diagram-toggle"; a CSS name needs a registered type, so
  # this port is a plain class whose root box carries the same name as a CSS
  # class, and the stylesheet matches on the class.
  class ChordDiagramToggle
    def initialize(&on_clicked)
      @on_clicked = on_clicked
    end

    def build
      root.tap do |box|
        box.append(button)

        button.signal_connect("clicked") { @on_clicked&.call }
      end
    end

    # The button itself, which the diagram needs so it can read whether this
    # fret is pressed and put the cell in a string's toggle group.
    def button
      @button ||= Gtk::ToggleButton.new.tap do |toggle|
        toggle.halign = :center
        toggle.valign = :center
        toggle.width_request = 38
        toggle.height_request = 38
        toggle.add_css_class("flat")
      end
    end

    def root
      @root ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.hexpand = true
        box.vexpand = true
        box.add_css_class("chord-diagram-toggle")
      end
    end
  end
end
