# frozen_string_literal: true

require "adwaita"

module Fretboard
  # PrimaryMenu is the model behind the main menu in the header bar.
  #
  # Ported from the `menu primary_menu` block at the end of upstream's
  # src/widgets/window.blp: a guitar-type section whose two items are the two
  # states of the win.set-handedness action, then the empty-chord item, then
  # the shortcuts and about items.
  class PrimaryMenu
    HANDEDNESS_ITEMS = {
      "Right-handed" => "right-handed",
      "Left-handed"  => "left-handed",
    }.freeze

    def build
      root.tap do |menu|
        menu.append_section("Guitar Type", handedness_section)
        menu.append_section(nil, chord_section)
        menu.append_section(nil, app_section)
      end
    end

    def handedness_section
      @handedness_section ||= Gio::Menu.new.tap do |section|
        HANDEDNESS_ITEMS.each do |label, target|
          section.append_item(handedness_item(label, target))
        end
      end
    end

    def chord_section
      @chord_section ||= Gio::Menu.new.tap do |section|
        # translators: "Empty" is a verb
        section.append("_Empty Chord", "win.empty-chord")
      end
    end

    def app_section
      @app_section ||= Gio::Menu.new.tap do |section|
        section.append("_Keyboard Shortcuts", "app.shortcuts")
        section.append("_About Fretboard", "win.about")
      end
    end

    def root = @root ||= Gio::Menu.new

    private

      def handedness_item(label, target)
        Gio::MenuItem.new(label, nil).tap do |item|
          item.set_action_and_target_value("win.set-handedness", GLib::Variant.new(target))
        end
      end
  end
end
