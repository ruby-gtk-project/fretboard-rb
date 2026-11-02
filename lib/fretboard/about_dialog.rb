# frozen_string_literal: true

require "adwaita"

module Fretboard
  # AboutDialog is the app's about window.
  #
  # Ported from show_about_dialog in upstream's src/widgets/window.rs. Upstream
  # builds the dialog with Adw.AboutDialog.from_appdata, which reads the
  # metainfo file out of the app's GResource bundle; this port has no resource
  # bundle, so the same fields are taken from
  # data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in and set directly, and
  # the developer, copyright, donation link and other-app entries upstream adds
  # on top are added the same way.
  class AboutDialog
    VERSION = "9.1"
    DEVELOPER = "Brage Fuglseth"
    SUMMARY = "Look up guitar chords"

    DESCRIPTION = "How was that chord played, again? Fretboard lets you find guitar " \
                  "chords by typing their names or plotting them on an interactive " \
                  "guitar neck. When you have identified a chord, you can experiment " \
                  "with changing it, see more ways to play it, or bookmark it to save " \
                  "it for later. No matter if you are a beginner or an advanced " \
                  "guitarist, you can use Fretboard to practice, learn, and master " \
                  "your favorite songs!"

    def present(parent) = build.present(parent)

    def build
      @build ||= root.tap do |dialog|
        dialog.add_link("Donate", "https://bragefuglseth.no/donate.html")

        dialog.add_other_app(
          "dev.bragefuglseth.Keypunch",
          # Translators: Metainfo for the app Keypunch.
          # <https://github.com/bragefuglseth/keypunch>
          "Keypunch",
          "Practice your typing skills",
        )
      end
    end

    def root
      @root ||= Adwaita::AboutDialog.new.tap do |dialog|
        dialog.application_name = "Fretboard"
        dialog.application_icon = APP_ID
        dialog.developer_name = DEVELOPER
        dialog.version = VERSION
        dialog.comments = DESCRIPTION
        dialog.developers = ["#{DEVELOPER} https://bragefuglseth.dev"]
        dialog.copyright = "© 2024 #{DEVELOPER}"
        dialog.license_type = Gtk::License::GPL_3_0
        # Translators: Replace "translator-credits" with your names, one name
        # per line
        dialog.translator_credits = "translator-credits"
        dialog.website = "https://apps.gnome.org/Fretboard"
        dialog.issue_url = "https://github.com/bragefuglseth/fretboard/issues"
      end
    end
  end
end
