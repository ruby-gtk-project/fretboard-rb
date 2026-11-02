# frozen_string_literal: true

require "adwaita"
require_relative "chord_ops"

module Fretboard
  # ChordPreview is the small read-only diagram used on the variants and
  # bookmarks pages: six string symbols, a grid of dots, the barre artwork and
  # the neck position beside it.
  #
  # Ported from upstream's src/widgets/chord_preview.blp and
  # src/widgets/chord_preview.rs.
  class ChordPreview
    STRINGS = 6
    FRETS = 5

    BARRE_LENGTHS = (2..6).to_a.freeze

    attr_accessor :chord_name
    attr_reader :chord

    def initialize(chord: nil, guitar_type: :right_handed, chord_name: "")
      @chord = chord
      @guitar_type = guitar_type
      @chord_name = chord_name
    end

    def build
      root.tap do |box|
        box.append(neck)
        box.append(neck_position_label)

        neck.tap do |column|
          column.append(top_row)
          column.append(overlay)

          top_row.tap do |row|
            top_symbols.each { |symbol| row.append(symbol) }
          end

          overlay.tap do |over|
            over.child = diagram_backdrop
            over.add_overlay(barre_overlay_stack)
            over.add_overlay(dots_grid)

            barre_overlay_stack.tap do |stack|
              stack.add_named(Gtk::Box.new(:horizontal, 0), "empty")
              BARRE_LENGTHS.each { |length| stack.add_named(barre_images.fetch(length), "barre-#{length}") }
            end

            dots_grid.tap do |grid|
              STRINGS.times do |string|
                FRETS.times do |fret|
                  grid.attach(
                    dot(string, fret),
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

        update_style

        unless @chord.nil?
          set_chord(@chord, @guitar_type)
        end
      end
    end

    # Draws a chord. Takes the guitar type as well, because a preview is built
    # fresh every time a page of them is shown.
    def set_chord(chord, guitar_type)
      @chord = chord
      @guitar_type = guitar_type

      reset_visuals

      ChordOps.lowest_fingered_fret(chord).then do |lowest|
        (lowest || 1).then do |neck_position|
          show_chord(ChordOps.adjust_chord(chord, neck_position), neck_position)
        end
      end
    end

    def top_symbols
      @top_symbols ||= Array.new(STRINGS) do
        Gtk::Image.new.tap do |symbol|
          symbol.valign = :center
          symbol.halign = :center
          symbol.hexpand = true
          symbol.add_css_class("fretboard-chord-diagram-top-toggle")
        end
      end
    end

    def dot(string, fret)
      dots[string][fret] ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.width_request = 20
        box.height_request = 20
        box.valign = :center
        box.halign = :center
        box.vexpand = true
        box.hexpand = true
        box.add_css_class("fretboard-chord-preview-dot")
      end
    end

    def dots = @dots ||= Array.new(STRINGS) { Array.new(FRETS) }

    def neck_position_label
      @neck_position_label ||= Gtk::Label.new("1").tap do |label|
        label.valign = :start
        label.margin_top = 22
        label.add_css_class("title-3")
      end
    end

    # The direction of the diagram is strictly visual.
    def top_row
      @top_row ||= Gtk::Box.new(:horizontal, 0).tap do |row|
        row.margin_bottom = 4
        row.direction = :ltr
      end
    end

    def dots_grid
      @dots_grid ||= Gtk::Grid.new.tap do |grid|
        grid.hexpand = true
        grid.vexpand = true
        grid.direction = :ltr
      end
    end

    def diagram_backdrop
      @diagram_backdrop ||= Gtk::Picture.new.tap do |picture|
        picture.can_shrink = false
        picture.margin_start = 12
        picture.margin_end = 12
        picture.accessible_role = :presentation
      end
    end

    def barre_overlay_stack
      @barre_overlay_stack ||= Gtk::Stack.new.tap do |stack|
        stack.margin_start = 12
        stack.margin_end = 12
      end
    end

    def barre_images
      @barre_images ||= BARRE_LENGTHS.to_h { |length| [length, barre_picture] }
    end

    def overlay = @overlay ||= Gtk::Overlay.new

    def neck
      @neck ||= Gtk::Box.new(:vertical, 0).tap do |column|
        column.hexpand = false
      end
    end

    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    def root
      @root ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :center
        box.valign = :center
        box.width_request = 180
        box.margin_start = 20
      end
    end

    private

      def barre_picture
        Gtk::Picture.new.tap do |picture|
          picture.valign = :start
          picture.halign = :end
        end
      end

      def show_chord(adjusted, neck_position)
        adjusted.each_with_index do |value, index|
          show_string(string_range[index], value)
        end

        neck_position_label.label = neck_position.to_s
        barre_images.each_value { |picture| picture.halign = barre_alignment }
        barre_overlay_stack.visible_child_name = barre_page(ChordOps.find_barre_length(adjusted))
      end

      def show_string(string, value)
        if value.nil?
          top_symbols[string].icon_name = "cross-large-symbolic"
        elsif value.zero?
          top_symbols[string].tap do |symbol|
            symbol.icon_name = "circle-outline-thick-symbolic"
            symbol.add_css_class("open")
          end
        else
          dot(string, value - 1).add_css_class("active")
        end
      end

      def string_range
        if @guitar_type == :left_handed
          (0...STRINGS).to_a.reverse
        else
          (0...STRINGS).to_a
        end
      end

      def reset_visuals
        top_symbols.each do |symbol|
          symbol.remove_css_class("open")
          symbol.icon_name = "dot-symbolic"
        end

        dots.flatten.compact.each { |box| box.remove_css_class("active") }

        neck_position_label.label = "1"
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
          diagram_backdrop.filename = Fretboard.asset_path("chord-preview-backdrop-#{suffix}.svg")

          barre_images.each do |length, picture|
            picture.filename = Fretboard.asset_path("prv-barre-#{length}-#{suffix}.svg")
          end
        end
      end
  end
end
