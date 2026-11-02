# frozen_string_literal: true

require "gtk4"
require "adwaita"
require_relative "shortcuts_dialog"
require_relative "style"
require_relative "window"

module Fretboard
  # Application is the app object: one window, the two application-wide
  # actions, and the accelerators for them and for the window's actions.
  #
  # Ported from upstream's src/application.rs. Adwaita::Application is broken
  # in the Ruby bindings, so the application object comes from Gtk and
  # Adwaita.init does what AdwApplication's startup would: it initialises
  # libadwaita's style manager and stylesheet.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    ACCELS = {
      "app.quit"           => ["<primary>q"],
      "app.shortcuts"      => ["<Control>question"],
      "window.close"       => ["<Ctrl>W"],
      "win.empty-chord"    => ["<Ctrl>E"],
      "win.focus-entry"    => ["<Ctrl>L"],
      "win.more-variants"  => ["<Alt>Return"],
      "win.bookmark-chord" => ["<Ctrl>D"],
      "win.bookmarks"      => ["<Ctrl><Alt>D"],
    }.freeze

    def build
      app.tap do |application|
        application.signal_connect("startup") { Adwaita.init }

        application.signal_connect("activate") do
          style.install
          setup_actions
          window.present
        end
      end
    end

    def run = build.run([])

    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)

    def window = @window ||= Window.new(app)

    def style = @style ||= Style.new

    def shortcuts_dialog = @shortcuts_dialog ||= ShortcutsDialog.new

    private

      def setup_actions
        app.tap do |application|
          application.add_action(action("quit") { application.quit })
          application.add_action(action("shortcuts") { shortcuts_dialog.present(window.window) })

          ACCELS.each { |name, accels| application.set_accels_for_action(name, accels) }
        end
      end

      def action(name, &handler)
        Gio::SimpleAction.new(name).tap do |simple|
          simple.signal_connect("activate") { handler.call }
        end
      end
  end
end
