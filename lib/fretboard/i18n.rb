# frozen_string_literal: true

require "adwaita"

module Fretboard
  # I18n is the port's gettext layer: the markers a translatable string is
  # written inside, and the catalogue they look messages up in.
  #
  # Ported from the bindtextdomain/bind_textdomain_codeset/textdomain block at
  # the top of upstream's src/main.rs, together with upstream's catalogue —
  # po/LINGUAS and the 37 po/*.po files, which this port vendors unchanged, and
  # po/POTFILES.in, which this port repoints at the Ruby sources. Upstream
  # compiles the catalogues into .mo files with msgfmt at build time and lets
  # the C library's gettext read them out of LOCALEDIR; this port reads the .po
  # files themselves, through Catalogue below, so a checkout, the installed gem
  # and the Nix package all translate with no build step, no .mo tree to
  # install and no gettext dependency at runtime.
  #
  # The markers are named after the ones the Ruby gettext gem defines, so that
  # rxgettext and the census both read them and so that a later move onto the
  # gem is a change of backend and not of call sites:
  #
  #   _("Bookmarks")                      gettextrs::gettext
  #   p_("shortcut dialog", "General")    the `context` attribute in a .ui file
  #   N_("Right-handed")                  marks a msgid without translating it
  #   NC_("shortcut dialog", "General")   marks one that has a context
  #   i18n_fmt(_("Open ({})"), note)      the i18n_fmt! macro
  #
  # Including the module also extends the including class, so that a class body
  # listing msgids in a constant can mark them with N_ and its instance methods
  # can translate them with _.
  module I18n
    # gettext keys a message that has a context by joining the two with EOT.
    CONTEXT_SEPARATOR = "\u0004"

    def self.included(base) = base.extend(self)

    # The catalogue the app is translating through: the first language po/ has
    # that the locale asked for, or an empty catalogue when it asked for none.
    def self.catalogue = @catalogue ||= Catalogue.for_locale

    module_function

    # The translation of msgid, or msgid itself when the catalogue has none —
    # which is what gettext returns too.
    def _(msgid) = I18n.catalogue.gettext(msgid)

    # The translation of msgid in a message context. Two messages that are the
    # same English in different places are two entries, and the context is the
    # part of the key that tells them apart.
    def p_(context, msgid) = I18n.catalogue.pgettext(context, msgid)

    # Marks a msgid for extraction without translating it: the shape a msgid
    # that lives in a constant needs, since the locale belongs to the moment
    # the string is shown and not to the moment the file was loaded.
    def N_(msgid) = msgid

    # Marks a msgid that has a message context, for the same reason. The
    # context is part of the key, so it is repeated at the p_ that translates
    # the marked msgid later.
    def NC_(_context, msgid) = msgid

    # Fills the `{}` placeholders of a template from left to right, the way
    # upstream's i18n_fmt! macro does. A translator may move the placeholders
    # around but not add or drop any, so the template decides how many are
    # filled and a surplus value is ignored.
    def i18n_fmt(template, *values)
      values.reduce(template) { |text, value| text.sub("{}", value.to_s) }
    end

    # Catalogue is one language's messages, read from its po/<language>.po.
    #
    # Ported from po/LINGUAS and the po/*.po files themselves. A .po file is
    # msgctxt/msgid/msgstr lines, each continuable by further quoted lines,
    # with a blank line between messages; the header is the message whose id is
    # empty, obsolete messages are commented out with "#~", and a message
    # flagged fuzzy is a guess that msgfmt leaves out of the .mo, so none of
    # the three becomes a translation here either.
    class Catalogue
      # The locale names that mean "no catalogue": the msgids themselves are
      # the English the app is written in.
      UNTRANSLATED_LOCALES = %w[C POSIX].freeze

      # The environment variables gettext reads, in its order of preference.
      # LANGUAGE holds a colon-separated list, the others one locale name.
      LOCALE_VARIABLES = %w[LANGUAGE LC_ALL LC_MESSAGES LANG].freeze

      # Every catalogue is UTF-8, which is what upstream declares with
      # bind_textdomain_codeset. The locale the app happens to start in does
      # not decide how the files are read.
      ENCODING = "UTF-8"

      # The escape sequences a .po file may use inside a quoted string.
      ESCAPES = {
        "n"  => "\n",
        "t"  => "\t",
        "r"  => "\r",
        "\"" => "\"",
        "\\" => "\\",
      }.freeze

      # The catalogue for the locale the app was started in. A locale with no
      # catalogue in po/ gets the empty one, whose lookups all fall back to
      # the msgid.
      def self.for_locale = new(language)

      # The language whose catalogue is in use, or nil when the app is
      # running untranslated.
      def self.language
        candidate_languages.find { |candidate| available_languages.include?(candidate) }
      end

      # The locale names the environment asks for, each one followed by the
      # bare language it belongs to, so that a user in pt_PT is served the pt
      # catalogue while a user in pt_BR is served the pt_BR one. An encoding
      # suffix (".UTF-8") and a modifier ("@euro") are not part of a
      # catalogue's name.
      def self.candidate_languages
        LOCALE_VARIABLES
          .flat_map { |name| ENV.fetch(name, "").split(":") }
          .map { |locale| locale.split(".").first.to_s.split("@").first.to_s }
          .reject { |locale| locale.empty? || UNTRANSLATED_LOCALES.include?(locale) }
          .flat_map { |locale| [locale, locale.split("_").first] }
          .uniq
      end

      # The languages po/ ships, as po/LINGUAS lists them. A language counts
      # only when its catalogue is there to be read.
      def self.available_languages
        linguas.select { |name| File.exist?(path(name)) }
      end

      # The language names in po/LINGUAS, one per line.
      def self.linguas
        File
          .readlines(linguas_path, chomp: true, encoding: ENCODING)
          .map(&:strip)
          .reject { |line| line.empty? || line.start_with?("#") }
      end

      def self.linguas_path = File.join(Fretboard.po_dir, "LINGUAS")

      def self.path(language) = File.join(Fretboard.po_dir, "#{language}.po")

      attr_reader :language

      def initialize(language)
        @language = language
      end

      def gettext(msgid) = messages.fetch(msgid, msgid)

      def pgettext(context, msgid)
        messages.fetch("#{context}#{CONTEXT_SEPARATOR}#{msgid}", msgid)
      end

      # Every translated message of this language, keyed the way gettext keys
      # them: the msgid, with the context and EOT in front of it when the
      # message has one.
      def messages
        @messages ||= read
      end

      private

        def read
          Entry.new.then do |entry|
            {}.tap do |messages|
              lines.each { |line| entry.read(line, messages) }
              # A file whose last message is not followed by a blank line
              # still ends that message.
              entry.read("", messages)
            end
          end
        end

        def lines
          if @language.nil?
            []
          else
            File.readlines(self.class.path(@language), chomp: true, encoding: ENCODING)
          end
        end

      # Entry accumulates the lines of one .po message and stores the finished
      # message when the blank line that ends it arrives.
        class Entry
          FIELDS = {
            /\Amsgctxt\s+"/        => :context,
            /\Amsgid\s+"/          => :msgid,
            /\Amsgstr(\[0\])?\s+"/ => :msgstr,
            /\Amsgid_plural\s+"/   => :ignored,
            /\Amsgstr\[\d+\]\s+"/  => :ignored,
          }.freeze

          def initialize = reset

          # Folds one line into the entry, storing the message into messages
          # when the line is the one that ends it.
          def read(line, messages)
            case line
            when /\A\s*\z/ then store(messages)
            when /\A#~/ then reset
            when /\A#,/ then flag(line)
            when /\A#/ then nil
            when *FIELDS.keys then start(line)
            when /\A"/ then append(line)
            end
          end

          private

            def start(line)
              @field = FIELDS.find { |pattern, _| pattern.match?(line) }.last
              @parts[@field] = quoted(line)
            end

            def append(line)
              @parts[@field] = @parts.fetch(@field, "") + quoted(line)
            end

            def flag(line)
              @fuzzy = @fuzzy || line.include?("fuzzy")
            end

            def store(messages)
              if translated?
                messages[key] = @parts[:msgstr]
              end

              reset
            end

            # The header (an empty msgid), an untranslated message and a fuzzy
            # one are all messages the user would see in English, so none of
            # them belongs in the catalogue.
            def translated?
              !@fuzzy && !@parts[:msgid].empty? && !@parts[:msgstr].empty?
            end

            def key
              if @parts[:context].empty?
                @parts[:msgid]
              else
                "#{@parts[:context]}#{CONTEXT_SEPARATOR}#{@parts[:msgid]}"
              end
            end

            def reset
              @parts = {
                context: "",
                msgid:   "",
                msgstr:  "",
                ignored: "",
              }
              @field = :ignored
              @fuzzy = false
            end

            # The body of a quoted .po string, with its escape sequences
            # resolved.
            def quoted(line)
              line[/"(.*)"\s*\z/, 1].to_s.gsub(/\\(.)/) do
                ESCAPES.fetch(Regexp.last_match(1), Regexp.last_match(1))
              end
            end
        end
    end
  end
end
