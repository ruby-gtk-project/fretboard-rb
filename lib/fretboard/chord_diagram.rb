# frozen_string_literal: true

require "adwaita"
require_relative "barre_spin"
require_relative "chord_diagram_toggle"
require_relative "chord_diagram_top_toggle"
require_relative "chord_ops"

module Fretboard
  # ChordDiagram is the interactive guitar neck: six string heads above the
  # nut, a grid of five frets below it, the barre artwork behind the dots, and
  # the neck-position spinner beside them.
  #
  # Ported from upstream's src/widgets/chord_diagram.blp and
  # src/widgets/chord_diagram.rs. Upstream's "user-changed-chord" signal is the
  # block handed to the constructor.
  class ChordDiagram
    STRINGS = 6
    FRETS = 5
    SCALE_SIZE = 12

    # Semitones above A for each open string, low E first.
    NOTE_OFFSETS = [7, 0, 5, 10, 2, 7].freeze

    NOTE_NAMES = %w[A A♯ B C C♯ D D♯ E F F♯ G G♯].freeze

    BARRE_LENGTHS = (2..6).to_a.freeze

    EMPTY_CHORD = [nil, nil, nil, nil, nil, nil].freeze

    attr_reader :chord, :guitar_type, :neck_position

    def initialize(&on_user_changed_chord)
      @on_user_changed_chord = on_user_changed_chord
      @chord = EMPTY_CHORD.dup
      @guitar_type = :right_handed
      @neck_position = 1
    end

    def build
      root.tap do |box|
        box.append(neck)
        box.append(barre_spin.build)

        neck.tap do |column|
          column.append(top_row)
          column.append(overlay)

          top_row.tap do |row|
            top_toggles.each { |toggle| row.append(toggle.build) }
          end

          overlay.tap do |over|
            over.child = diagram_backdrop
            over.add_overlay(barre_overlay_stack)
            over.add_overlay(grid)

            barre_overlay_stack.tap do |stack|
              stack.add_named(Gtk::Box.new(:horizontal, 0), "empty")
              BARRE_LENGTHS.each { |length| stack.add_named(barre_image(length), "barre-#{length}") }
            end

            grid.tap do |cells|
              STRINGS.times do |string|
                FRETS.times do |fret|
                  cells.attach(
                    toggle(string, fret).build,
                    string,
                    fret,
                    1,
                    1,
                  )
                end
              end
            end
          end
        end

        style_manager.tap do |manager|
          manager.signal_connect("notify::dark") { update_style }
          manager.signal_connect("notify::high-contrast") { update_style }
        end

        group_toggles
        update_style
        update_visuals
      end
    end

    # Shows a chord, moving the diagram to the chord's own neck position. This
    # is upstream's set_chord.
    def chord=(chord)
      @chord = chord
      @neck_position = ChordOps.lowest_fingered_fret(chord) || 1
      barre_spin.value = @neck_position

      update_visuals
      update_barre_visuals
      @chord
    end

    # :right_handed draws the low E on the left, :left_handed on the right.
    def guitar_type=(guitar_type)
      @guitar_type = guitar_type
      update_visuals

      barre_images.each_value { |picture| picture.halign = barre_alignment }
      @guitar_type
    end

    # Moves the whole chord one fret up or down the neck, which is what the
    # spinner beside the diagram does. `message` is :increment or :decrement.
    def update_neck_position(message)
      change(message).then do |amount|
        if @chord.all? { |value| value.nil? || value.zero? }
          @neck_position += amount
          update_visuals
        else
          self.chord = moved_chord(amount)
        end
      end
    end

    def top_toggles
      @top_toggles ||= Array.new(STRINGS) do |index|
        ChordDiagramTopToggle.new(STRINGS - index, NOTE_NAMES[NOTE_OFFSETS[index]]) do
          user_changed_chord
        end
      end
    end

    def toggle(string, fret)
      toggles[string][fret] ||= ChordDiagramToggle.new { user_changed_chord }
    end

    def toggles = @toggles ||= Array.new(STRINGS) { Array.new(FRETS) }

    def barre_spin
      @barre_spin ||= BarreSpin.new { |message| spin_changed(message) }.tap do |spin|
        spin.root.valign = :start
        spin.root.margin_end = 10
        spin.root.margin_top = 17
      end
    end

    # The direction of the diagram is strictly visual, so the row of string
    # heads and the fret grid stay left-to-right in right-to-left locales.
    def top_row
      @top_row ||= Gtk::Box.new(:horizontal, 0).tap do |row|
        row.homogeneous = true
        row.margin_bottom = 6
        row.direction = :ltr
      end
    end

    def grid
      @grid ||= Gtk::Grid.new.tap do |cells|
        cells.hexpand = true
        cells.vexpand = true
        cells.direction = :ltr
      end
    end

    def diagram_backdrop
      @diagram_backdrop ||= Gtk::Picture.new.tap do |picture|
        picture.can_shrink = false
        picture.margin_start = 25
        picture.margin_end = 25
        picture.accessible_role = :presentation
      end
    end

    def barre_overlay_stack
      @barre_overlay_stack ||= Gtk::Stack.new.tap do |stack|
        stack.transition_type = :crossfade
        stack.transition_duration = 150
        stack.margin_start = 25
        stack.margin_end = 25
      end
    end

    def barre_images
      @barre_images ||= BARRE_LENGTHS.to_h { |length| [length, barre_picture] }
    end

    def overlay = @overlay ||= Gtk::Overlay.new

    def neck = @neck ||= Gtk::Box.new(:vertical, 0)

    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    def root
      @root ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.hexpand = false
        box.halign = :end
      end
    end

    private

      def barre_image(length) = barre_images.fetch(length)

      def barre_picture
        Gtk::Picture.new.tap do |picture|
          picture.halign = :end
          picture.valign = :start
        end
      end

      def group_toggles
        STRINGS.times do |string|
          FRETS.times { |fret| toggle(string, fret).button.set_group(top_toggles[string].button) }
        end
      end

      def user_changed_chord
        update_chord
        @on_user_changed_chord&.call
      end

      def spin_changed(message)
        update_neck_position(message)
        @on_user_changed_chord&.call
      end

      def change(message)
        if message == :increment
          1
        else
          -1
        end
      end

      def moved_chord(amount)
        @chord.map do |value|
          if value.nil? || value.zero?
            value
          else
            value + amount
          end
        end
      end

      # Reads the chord back off the toggles, which is what happens after every
      # click on the diagram.
      def update_chord
        @chord = string_range.map { |string| string_value(string) }
        update_barre_visuals
      end

      def string_value(string)
        case top_toggles[string].state
        when :muted then nil
        when :open then 0
        else pressed_fret(string)
        end
      end

      # The fret a string is held down at, or nil when the string has neither a
      # pressed fret nor a state on its head — which the group of toggles makes
      # rare, but not impossible.
      def pressed_fret(string)
        FRETS.times.find { |fret| toggle(string, fret).button.active? }.then do |fret|
          if fret.nil?
            nil
          else
            fret + @neck_position
          end
        end
      end

      # The strings in display order: reversed for a left-handed guitar.
      def string_range
        if @guitar_type == :left_handed
          (0...STRINGS).to_a.reverse
        else
          (0...STRINGS).to_a
        end
      end

      def update_visuals
        ChordOps.adjust_chord(@chord, @neck_position).then do |adjusted|
          string_range.each_with_index do |string, index|
            show_string(string, adjusted[index])
            label_string(string, index)
          end
        end
      end

      def show_string(string, value)
        if value.nil? || value > FRETS
          top_toggles[string].state = :muted
        elsif value.zero?
          top_toggles[string].state = :open
        else
          toggle(string, value - 1).button.active = true
        end
      end

      # The note names follow the display position, not the string, so the
      # names stay in the same places when the diagram is flipped over.
      def label_string(string, index)
        NOTE_OFFSETS[index].then do |offset|
          top_toggles[string].note_name = NOTE_NAMES[offset % SCALE_SIZE]

          FRETS.times do |fret|
            toggle(string, fret).button.tooltip_text = NOTE_NAMES[(offset + fret + @neck_position) % SCALE_SIZE]
          end
        end
      end

      def update_barre_visuals
        ChordOps.find_barre_length(ChordOps.adjust_chord(@chord, @neck_position)).then do |length|
          barre_overlay_stack.visible_child_name = barre_page(length)
        end
      end

      def barre_page(length)
        if BARRE_LENGTHS.include?(length)
          "barre-#{length}"
        else
          "empty"
        end
      end

      def barre_alignment
        if @guitar_type == :left_handed
          :start
        else
          :end
        end
      end

      # In high contrast mode, just use the dark mode assets for light mode and
      # vice versa.
      def style_suffix
        if style_manager.dark? == style_manager.high_contrast?
          "light"
        else
          "dark"
        end
      end

      def update_style
        style_suffix.then do |suffix|
          diagram_backdrop.filename = Fretboard.asset_path("chord-diagram-backdrop-#{suffix}.svg")

          barre_images.each do |length, picture|
            picture.filename = Fretboard.asset_path("barre-#{length}-#{suffix}.svg")
          end
        end
      end
  end
end
