# frozen_string_literal: true

require "adwaita"
require_relative "i18n"

module Fretboard
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # A direct port of upstream's data/resources/shortcuts-dialog.ui: an
  # Adw.ShortcutsDialog with three sections, whose items name actions rather
  # than accelerators, so the accelerators shown are the ones the application
  # binds to those actions.
  class ShortcutsDialog
    include I18n

    # Every string in upstream's .ui carries the "shortcut dialog" message
    # context, so every one of them is looked up with p_ below. They are marked
    # here and translated as each section and item is built.
    CONTEXT = "shortcut dialog"

    SECTIONS = [
      {
        title: NC_("shortcut dialog", "General"),
        items: [
          [NC_("shortcut dialog", "Open Menu"), accelerator: "F10"],
          # translators: "Empty" is a verb
          [NC_("shortcut dialog", "Empty Chord"), action: "win.empty-chord"],
          [NC_("shortcut dialog", "View Chord Variants"), action: "win.more-variants"],
          [NC_("shortcut dialog", "Focus Entry"), action: "win.focus-entry"],
        ],
      },
      {
        title: nil,
        items: [
          [NC_("shortcut dialog", "Bookmark Chord"), action: "win.bookmark-chord"],
          [NC_("shortcut dialog", "View Bookmarks"), action: "win.bookmarks"],
        ],
      },
      {
        title: nil,
        items: [
          [NC_("shortcut dialog", "Keyboard Shortcuts"), action: "app.shortcuts"],
          [NC_("shortcut dialog", "Close Window"), action: "window.close"],
          [NC_("shortcut dialog", "Quit"), action: "app.quit"],
        ],
      },
    ].freeze

    def build
      @build ||= root.tap do |dialog|
        SECTIONS.each { |definition| dialog.add(section(definition)) }
      end
    end

    def present(parent) = build.present(parent)

    # Every Adwaita::ShortcutsItem the dialog was built with, in the order
    # SECTIONS lists them, so a test can assert on the dialog's actual
    # widgets rather than re-deriving the expected text from SECTIONS itself.
    def items = @items ||= []

    def root
      @root ||= Adwaita::ShortcutsDialog.new.tap do |dialog|
        # Upstream's .ui leaves the title to libadwaita, which translates its
        # own default through its own catalogue. The port says it, so it says
        # it with the same words as the item of that name.
        dialog.title = p_("shortcut dialog", "Keyboard Shortcuts")
      end
    end

    private

      def section(definition)
        Adwaita::ShortcutsSection.new.tap do |section|
          unless definition[:title].nil?
            section.title = p_(CONTEXT, definition[:title])
          end

          definition[:items].each do |title, options|
            section.add(item(p_(CONTEXT, title), options))
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

          items << shortcut
        end
      end
  end
end
