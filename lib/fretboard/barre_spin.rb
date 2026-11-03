# frozen_string_literal: true

require "adwaita"
require_relative "i18n"

module Fretboard
  # BarreSpin is the spinner beside the neck that says which fret the top of
  # the diagram is: two buttons and the number between them.
  #
  # Ported from upstream's src/widgets/barre_spin.blp and
  # src/widgets/barre_spin.rs. Upstream drives the label and the two buttons'
  # sensitivity with property bindings on a "value" property; without a GObject
  # property, `value=` updates all three directly.
  class BarreSpin
    include I18n

    MIN_VALUE = 1
    MAX_VALUE = 12

    attr_reader :value

    # The block is called with :increment or :decrement when the user moves
    # the neck position, which is upstream's "user-changed-value" signal.
    def initialize(&on_user_changed_value)
      @on_user_changed_value = on_user_changed_value
      @value = MIN_VALUE
    end

    def build
      root.tap do |box|
        box.append(column)

        column.tap do |col|
          col.append(decrement_button)
          col.append(label)
          col.append(increment_button)

          decrement_button.signal_connect("clicked") { change(-1, :decrement) }
          increment_button.signal_connect("clicked") { change(1, :increment) }
        end

        refresh
      end
    end

    def value=(value)
      @value = value.clamp(MIN_VALUE, MAX_VALUE)
      refresh
      @value
    end

    def label
      @label ||= Gtk::Label.new(MIN_VALUE.to_s).tap do |text|
        text.selectable = true
        text.halign = :center
        text.valign = :center
      end
    end

    def decrement_button
      @decrement_button ||= spin_button("up-large-symbolic", _("Move Up"))
    end

    def increment_button
      @increment_button ||= spin_button("down-large-symbolic", _("Move Down"))
    end

    def column = @column ||= Gtk::Box.new(:vertical, 0)

    def root
      @root ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.accessible_role = :spin_button
        box.add_css_class("barre-spin")
      end
    end

    private

      def change(amount, message)
        self.value = @value + amount
        @on_user_changed_value&.call(message)
      end

      def refresh
        label.label = @value.to_s
        increment_button.sensitive = @value < MAX_VALUE
        decrement_button.sensitive = @value > MIN_VALUE
      end

      def spin_button(icon_name, tooltip)
        Gtk::Button.new.tap do |button|
          button.icon_name = icon_name
          button.tooltip_text = tooltip
          button.halign = :center
          button.valign = :center
          button.width_request = 38
          button.height_request = 38
          button.add_css_class("flat")
        end
      end
  end
end
