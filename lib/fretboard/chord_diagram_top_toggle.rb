# frozen_string_literal: true

require "adwaita"
require_relative "i18n"

module Fretboard
  # ChordDiagramTopToggle is the head of one string, above the nut: a
  # three-state toggle that cycles a string between not open, open and muted.
  #
  # Ported from upstream's src/widgets/chord_diagram_top_toggle.blp and
  # src/widgets/chord_diagram_top_toggle.rs, including the two flags that keep
  # the three states in step with a two-state GtkToggleButton. GTK emits
  # "toggled" from the button's own "clicked" class handler, which runs before
  # connected handlers, so a click that changes the active state is seen by
  # "toggled" first and the "clicked" handler then leaves the state alone; a
  # click on an already-active toggle emits no "toggled" at all, and that is
  # the click that flips open to muted and back.
  class ChordDiagramTopToggle
    include I18n

    STATES = %i[off open muted].freeze

    # The tooltip upstream shows for each state, with `{}` standing in for the
    # note the string sounds. Marked here and translated at display, so the
    # locale that matters is the one the tooltip is shown in.
    TOOLTIPS = {
      # translators: The text between the `{}` markers is the note of the
      # string that is not open.
      off:   N_("Not Open ({})"),
      # translators: The text between the `{}` markers is the note of the open
      # string. "Open" is an adjective, not a verb.
      open:  N_("Open ({})"),
      # translators: The text between the `{}` markers is the note of the
      # muted string.
      muted: N_("Muted ({})"),
    }.freeze

    ICONS = {
      off:   "dot-symbolic",
      open:  "circle-outline-thick-symbolic",
      muted: "cross-large-symbolic",
    }.freeze

    attr_reader :state

    # The string this toggle heads, numbered 6 to 1 the way upstream's
    # `number` property is. Upstream puts it in the button's accessible label;
    # see update_tooltip for why the port cannot.
    attr_reader :number

    def initialize(number, note_name, &on_clicked)
      @number = number
      @note_name = note_name
      @on_clicked = on_clicked
      @state = :off
      @programmatically_toggled = false
      @recently_toggled = false
    end

    def build
      root.tap do |box|
        box.append(overlay)

        overlay.tap do |over|
          over.child = button
          over.add_overlay(icon_stack)

          icon_stack.tap do |stack|
            STATES.each { |state| stack.add_named(icon(state), state.to_s) }
          end
        end

        button.tap do |toggle|
          toggle.signal_connect("toggled") { on_toggled }
          toggle.signal_connect("clicked") { on_clicked }
        end

        update_icon
      end
    end

    def button
      @button ||= Gtk::ToggleButton.new.tap do |toggle|
        toggle.width_request = 38
        toggle.height_request = 38
        toggle.add_css_class("flat")
      end
    end

    # Puts the toggle in a state without the clicks that normally drive it,
    # which is how the diagram shows a chord it was handed.
    def state=(state)
      @programmatically_toggled = true
      button.active = state != :off
      @programmatically_toggled = false

      @state = state
      update_icon

      @recently_toggled = false
    end

    def note_name=(note_name)
      @note_name = note_name
      update_tooltip
    end

    def update_icon
      icon_stack.visible_child_name = @state.to_s
      update_tooltip
    end

    def icon_stack
      @icon_stack ||= Gtk::Stack.new.tap do |stack|
        stack.can_target = false
        stack.transition_type = :crossfade
        stack.transition_duration = 150
      end
    end

    def overlay = @overlay ||= Gtk::Overlay.new

    def root
      @root ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :center
        box.hexpand = true
        box.add_css_class("fretboard-chord-diagram-top-toggle")
      end
    end

    private

      def on_toggled
        unless @programmatically_toggled
          @state = active_state
          @recently_toggled = true
          update_icon
        end
      end

      def on_clicked
        unless @recently_toggled
          @state = cycled_state
        end

        @recently_toggled = false
        update_icon
        @on_clicked&.call
      end

      def active_state
        if button.active?
          :open
        else
          :off
        end
      end

      def cycled_state
        case @state
        when :open then :muted
        when :muted then :open
        else :off
        end
      end

      # The tooltip is upstream's, verbatim and translated. Upstream also sets
      # an accessible label that names the string number ("String 1, Open")
      # with gtk_accessible_update_property, which the Ruby bindings cannot
      # call — update_property takes a C array of enum values and the
      # introspection loader raises NotImplementedError for it — so the number
      # reaches assistive technology through the diagram's layout rather than
      # through this widget.
      def update_tooltip
        button.tooltip_text = tooltip_text
      end

      def tooltip_text = i18n_fmt(_(TOOLTIPS.fetch(@state)), @note_name)

      def icon(state)
        Gtk::Image.new.tap do |image|
          image.icon_name = ICONS.fetch(state)

          if state == :open
            image.add_css_class("open")
          end
        end
      end
  end
end
