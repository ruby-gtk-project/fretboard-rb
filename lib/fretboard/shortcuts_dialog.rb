# frozen_string_literal: true

require "adwaita"

module Fretboard
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # A direct port of upstream's data/resources/shortcuts-dialog.ui: an
  # Adw.ShortcutsDialog with three sections, whose items name actions rather
  # than accelerators, so the accelerators shown are the ones the application
  # binds to those actions.
  class ShortcutsDialog
    SECTIONS = [
      {
        title: "General",
        items: [
          ["Open Menu", accelerator: "F10"],
          # translators: "Empty" is a verb
          ["Empty Chord", action: "win.empty-chord"],
          ["View Chord Variants", action: "win.more-variants"],
          ["Focus Entry", action: "win.focus-entry"],
        ],
      },
      {
        title: nil,
        items: [
          ["Bookmark Chord", action: "win.bookmark-chord"],
          ["View Bookmarks", action: "win.bookmarks"],
        ],
      },
      {
        title: nil,
        items: [
          ["Keyboard Shortcuts", action: "app.shortcuts"],
          ["Close Window", action: "window.close"],
          ["Quit", action: "app.quit"],
        ],
      },
    ].freeze

    def build
      @build ||= root.tap do |dialog|
        SECTIONS.each { |definition| dialog.add(section(definition)) }
      end
    end

    def present(parent) = build.present(parent)

    def root
      @root ||= Adwaita::ShortcutsDialog.new.tap do |dialog|
        dialog.title = "Keyboard Shortcuts"
      end
    end

    private

      def section(definition)
        Adwaita::ShortcutsSection.new.tap do |section|
          unless definition[:title].nil?
            section.title = definition[:title]
          end

          definition[:items].each do |title, options|
            section.add(item(title, options))
          end
        end
      end

      # Positional, not keyword, arguments — even though the error a
      # no-argument new raises advertises the signatures as
      # "title: utf8, accelerator: utf8". An item that names an action is
      # created with an empty accelerator and gets its real one from the
      # action.
      def item(title, options)
        Adwaita::ShortcutsItem.new(title, options.fetch(:accelerator, "")).tap do |shortcut|
          unless options[:action].nil?
            shortcut.action_name = options[:action]
          end
        end
      end
  end
end
