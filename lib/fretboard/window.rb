# frozen_string_literal: true

require "adwaita"
require_relative "about_dialog"
require_relative "bookmarks"
require_relative "chord_diagram"
require_relative "chord_name_algorithm"
require_relative "chord_name_entry"
require_relative "chord_ops"
require_relative "chord_preview_button"
require_relative "database"
require_relative "primary_menu"
require_relative "settings"

module Fretboard
  # Window is the app's only window: the chord view, the variants page and the
  # bookmarks page, in a navigation stack.
  #
  # Ported from upstream's src/widgets/window.blp and src/widgets/window.rs.
  # The window's actions are the same, and so are the three pages and their
  # tags; upstream's GSettings-backed "handedness" property is backed by this
  # port's JSON settings file instead.
  class Window
    EMPTY_CHORD = [nil, nil, nil, nil, nil, nil].freeze

    HANDEDNESS = {
      "right-handed" => :right_handed,
      "left-handed"  => :left_handed,
    }.freeze

    NO_VARIANTS_DESCRIPTION = "There are no chords with this name in Fretboard’s built-in " \
                              "chord set. If you think there should be, " \
                              "<a href=\"https://github.com/bragefuglseth/fretboard/issues\">" \
                              "reach out</a>."

    def initialize(app)
      @app = app
    end

    def build
      window.tap do |win|
        win.content = navigation_stack

        navigation_stack.tap do |stack|
          stack.add(chord_view_page)
          stack.add(variants_page)
          stack.add(bookmarks_page)
        end

        build_chord_view
        build_variants_page
        build_bookmarks_page
        install_actions

        win.signal_connect("close-request") { on_close_request }

        apply_handedness(settings.handedness)
        refresh_bookmarks_button
        load_stored_chord
      end
    end

    def present = build.present

    # ─── Window and chrome ────────────────────────────────────────────────

    def window
      @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
        win.title = "Fretboard"
        win.icon_name = APP_ID
        win.width_request = 360
        win.height_request = 294
        settings.apply_to(win)
      end
    end

    def navigation_stack = @navigation_stack ||= Adwaita::NavigationView.new

    def chord_view_page
      @chord_view_page ||= Adwaita::NavigationPage.new(chord_toolbar, "Fretboard").tap do |page|
        page.tag = "chord-view"
      end
    end

    def variants_page
      @variants_page ||= Adwaita::NavigationPage.new(variants_toolbar, "").tap do |page|
        page.tag = "more-variants"
      end
    end

    def bookmarks_page
      @bookmarks_page ||= Adwaita::NavigationPage.new(bookmarks_toolbar, "Bookmarks").tap do |page|
        page.tag = "bookmarks"
      end
    end

    def chord_toolbar = @chord_toolbar ||= Adwaita::ToolbarView.new
    def variants_toolbar = @variants_toolbar ||= Adwaita::ToolbarView.new
    def bookmarks_toolbar = @bookmarks_toolbar ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def variants_header_bar = @variants_header_bar ||= Adwaita::HeaderBar.new
    def bookmarks_header_bar = @bookmarks_header_bar ||= Adwaita::HeaderBar.new

    def bookmarks_button
      @bookmarks_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "library-symbolic"
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "open-menu-symbolic"
        button.tooltip_text = "Main Menu"
        button.primary = true
      end
    end

    # ─── Chord view ───────────────────────────────────────────────────────

    def chord_scroll
      @chord_scroll ||= Gtk::ScrolledWindow.new.tap do |scroll|
        scroll.hscrollbar_policy = :never
      end
    end

    def chord_box
      @chord_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.valign = :center
      end
    end

    # Diagram plus spinner, padded by an amount equivalent to the spinner's
    # width: 360 + 48.
    def diagram_clamp
      @diagram_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.maximum_size = 408
        clamp.vexpand = true
        clamp.unit = :px
      end
    end

    def entry_clamp
      @entry_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.maximum_size = 360
        clamp.margin_top = 35
        clamp.margin_start = 25
        clamp.margin_end = 25
      end
    end

    def diagram = @diagram ||= ChordDiagram.new { load_name_from_chord }

    def entry
      @entry ||= ChordNameEntry.new(
        on_activate:           -> { load_chord_from_name },
        on_enharmonic_clicked: -> { refresh_star_toggle },
      )
    end

    def feedback_stack
      @feedback_stack ||= Gtk::Stack.new.tap do |stack|
        stack.transition_type = :crossfade
        stack.transition_duration = 150
        stack.margin_top = 8
        stack.margin_bottom = 15
      end
    end

    def feedback_label
      @feedback_label ||= Gtk::Label.new("Chord not found").tap do |label|
        label.wrap = true
        label.justify = :center
        label.add_css_class("dimmed")
      end
    end

    def chord_actions
      @chord_actions ||= Gtk::Box.new(:horizontal, 12).tap do |box|
        box.halign = :center
      end
    end

    def star_toggle
      @star_toggle ||= Gtk::ToggleButton.new.tap do |toggle|
        toggle.action_name = "win.bookmark-chord"
        toggle.add_css_class("flat")
        toggle.add_css_class("fretboard-star-toggle")
      end
    end

    def more_variants_button
      @more_variants_button ||= Gtk::Button.new.tap do |button|
        button.action_name = "win.more-variants"
        button.add_css_class("flat")
      end
    end

    def more_variants_box = @more_variants_box ||= Gtk::Box.new(:horizontal, 6)

    def more_variants_label
      @more_variants_label ||= Gtk::Label.new("View _Variants").tap do |label|
        label.use_underline = true
      end
    end

    def more_variants_image
      @more_variants_image ||= Gtk::Image.new.tap do |image|
        image.icon_name = "go-next-symbolic"
        image.accessible_role = :presentation
      end
    end

    # ─── Variants and bookmarks pages ─────────────────────────────────────

    def variants_stack = @variants_stack ||= Gtk::Stack.new

    def no_variants_page
      @no_variants_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = "fretboard-symbolic"
        page.title = "No Variants"
        # translators: The text between the `<a>` tags becomes a link to the
        # app's issue tracker. Include both of the tags.
        page.description = NO_VARIANTS_DESCRIPTION
      end
    end

    def variants_scroll
      @variants_scroll ||= Gtk::ScrolledWindow.new.tap do |scroll|
        scroll.hscrollbar_policy = :never
      end
    end

    def bookmarks_scroll
      @bookmarks_scroll ||= Gtk::ScrolledWindow.new.tap do |scroll|
        scroll.hscrollbar_policy = :never
      end
    end

    def variants_clamp = @variants_clamp ||= page_clamp
    def bookmarks_clamp = @bookmarks_clamp ||= page_clamp

    def variants_container = @variants_container ||= preview_container
    def bookmarks_container = @bookmarks_container ||= preview_container

    # ─── Models ───────────────────────────────────────────────────────────

    def settings = @settings ||= Settings.new
    def database = @database ||= Database.new
    def bookmarks = @bookmarks ||= Bookmarks.new
    def primary_menu = @primary_menu ||= PrimaryMenu.new
    def about_dialog = @about_dialog ||= AboutDialog.new

    private

      def page_clamp
        Adwaita::Clamp.new.tap do |clamp|
          clamp.maximum_size = 1000
          clamp.tightening_threshold = 700
          clamp.unit = :px
        end
      end

      def preview_container
        Gtk::FlowBox.new.tap do |container|
          container.selection_mode = :none
          container.homogeneous = true
          container.margin_top = 12
          container.margin_bottom = 24
          container.margin_start = 24
          container.margin_end = 24
          container.row_spacing = 12
          container.column_spacing = 12
          container.valign = :start
        end
      end

      def build_chord_view
        chord_toolbar.tap do |toolbar|
          toolbar.add_top_bar(header_bar)
          toolbar.content = chord_scroll

          header_bar.tap do |bar|
            bar.pack_start(bookmarks_button)
            bar.pack_end(menu_button)

            menu_button.menu_model = primary_menu.build
          end

          chord_scroll.child = chord_box

          chord_box.tap do |box|
            box.append(diagram_clamp)
            box.append(entry_clamp)
            box.append(feedback_stack)

            diagram_clamp.child = diagram.build
            entry_clamp.child = entry.build

            feedback_stack.tap do |stack|
              stack.add_named(Gtk::Box.new(:horizontal, 0), "empty")
              stack.add_named(feedback_label, "label")
              stack.add_named(chord_actions, "chord-actions")
            end

            chord_actions.tap do |actions|
              actions.append(star_toggle)
              actions.append(more_variants_button)

              star_toggle.signal_connect("toggled") { refresh_star_appearance }

              more_variants_button.child = more_variants_box

              more_variants_box.tap do |contents|
                contents.append(more_variants_label)
                contents.append(more_variants_image)
              end
            end
          end
        end

        refresh_star_appearance
      end

      def build_variants_page
        variants_toolbar.tap do |toolbar|
          toolbar.add_top_bar(variants_header_bar)
          toolbar.content = variants_stack

          variants_stack.tap do |stack|
            stack.add_named(no_variants_page, "no-variants")
            stack.add_named(variants_scroll, "variants")
          end

          variants_scroll.child = variants_clamp
          variants_clamp.child = variants_container
        end
      end

      def build_bookmarks_page
        bookmarks_toolbar.tap do |toolbar|
          toolbar.add_top_bar(bookmarks_header_bar)
          toolbar.content = bookmarks_scroll

          bookmarks_scroll.child = bookmarks_clamp
          bookmarks_clamp.child = bookmarks_container
        end
      end

      # ─── Actions ────────────────────────────────────────────────────────

      def install_actions
        window.tap do |win|
          win.add_action(handedness_action)

          {
            "empty-chord"    => -> { empty_chord },
            "chord-view"     => -> { chord_view },
            "focus-entry"    => -> { focus_entry },
            "more-variants"  => -> { more_variants },
            "bookmarks"      => -> { show_bookmarks },
            "bookmark-chord" => -> { bookmark_chord },
            "about"          => -> { about_dialog.present(win) },
          }.each do |name, handler|
            win.add_action(action(name, &handler))
          end
        end
      end

      def action(name, &handler)
        Gio::SimpleAction.new(name).tap do |simple|
          simple.signal_connect("activate") { handler.call }
        end
      end

      # Upstream installs a property action on its GSettings-bound "handedness"
      # property; here the stateful action is the single source of truth and
      # writes the setting itself.
      def handedness_action
        @handedness_action ||= Gio::SimpleAction.new(
          "set-handedness",
          GLib::VariantType.new("s"),
          GLib::Variant.new(settings.handedness),
        ).tap do |simple|
          simple.signal_connect("change-state") { |action, value| change_handedness(action, value) }
        end
      end

      # The value a "change-state" handler is handed arrives already unwrapped
      # as a Ruby String, and assigning that String back to `state` segfaults
      # in the bindings — the state has to be wrapped in a Variant again.
      def change_handedness(action, value)
        action.state = GLib::Variant.new(value)
        settings.handedness = value
        apply_handedness(value)
      end

      def apply_handedness(handedness)
        diagram.guitar_type = HANDEDNESS.fetch(handedness, :right_handed)
      end

      # ─── Action implementations ─────────────────────────────────────────

      def focus_entry = entry.entry.grab_focus

      def chord_view = navigation_stack.push_by_tag("chord-view")

      def empty_chord
        diagram.chord = EMPTY_CHORD.dup
        entry.overwrite_text("")
        feedback_stack.visible_child_name = "empty"

        refresh_star_toggle
      end

      def bookmark_chord
        if on_chord_view?
          toggle_bookmark
        end
      end

      def toggle_bookmark
        current_bookmark.then do |bookmark|
          star_toggle.grab_focus

          if bookmarks.include?(bookmark)
            bookmarks.remove(bookmark)
          else
            bookmarks.add(bookmark)
          end

          bookmarks.save
          refresh_bookmarks_button
          refresh_star_toggle
        end
      end

      def current_bookmark = Bookmark.new(entry.serialized_buffer_text, diagram.chord)

      def refresh_bookmarks_button
        bookmarks_button.tap do |button|
          if bookmarks.empty?
            button.action_name = nil
            button.tooltip_text = "No Bookmarks"
          else
            button.action_name = "win.bookmarks"
            button.tooltip_text = "Bookmarks"
          end

          button.sensitive = !bookmarks.empty?
        end
      end

      def refresh_star_toggle
        star_toggle.active = bookmarks.include?(current_bookmark)
        refresh_star_appearance
      end

      # Upstream binds the toggle's "active" property to its icon and tooltip;
      # the bindings have no property-binding transform, so the two follow the
      # state here.
      def refresh_star_appearance
        if star_toggle.active?
          star_toggle.icon_name = "star-large-symbolic"
          star_toggle.tooltip_text = "Remove Bookmark"
        else
          star_toggle.icon_name = "star-outline-rounded-symbolic"
          star_toggle.tooltip_text = "Bookmark"
        end
      end

      def load_chord_from_name
        database.positions_from_name(entry.serialized_buffer_text).first.then do |chord|
          if chord.nil?
            diagram.chord = EMPTY_CHORD.dup
            feedback_stack.visible_child_name = "label"
          else
            diagram.chord = chord.dup
            feedback_stack.visible_child_name = "chord-actions"
          end
        end

        refresh_star_toggle
      end

      def load_name_from_chord
        name_for(diagram.chord).then do |name|
          entry.overwrite_text(name)

          if name.empty?
            feedback_stack.visible_child_name = "label"
          else
            feedback_stack.visible_child_name = "chord-actions"
          end
        end

        refresh_star_toggle
      end

      # The database first, then the naming algorithm, then nothing at all.
      def name_for(chord)
        database.name_from_chord(chord).then do |name|
          (name || ChordNameAlgorithm.calculate_chord_name(chord) || "")
        end
      end

      def more_variants
        entry.serialized_buffer_text.then do |chord_name|
          if !chord_name.empty? && on_chord_view?
            show_variants(chord_name)
          end
        end
      end

      def show_variants(chord_name)
        database.positions_from_name(chord_name).then do |variants|
          variants_stack.visible_child_name = variants_page_name(variants)
          clear(variants_container)

          variants.each do |variant|
            variants_container.insert(variant_button(variant, chord_name).build, -1)
          end

          variants_page.title = ChordOps.prettify_chord_name(chord_name)
          scroll_to_top(variants_scroll)
          navigation_stack.push_by_tag("more-variants")
        end
      end

      def variants_page_name(variants)
        if variants.empty?
          "no-variants"
        else
          "variants"
        end
      end

      def variant_button(variant, chord_name)
        ChordPreviewButton.new(
          chord:       variant,
          name:        chord_name,
          guitar_type: diagram.guitar_type,
        ) { |chord, name| open_variant(chord, name) }
      end

      def open_variant(chord, name)
        diagram.chord = chord.dup
        entry.overwrite_text(name)
        refresh_star_toggle
        navigation_stack.pop
      end

      def show_bookmarks
        if on_chord_view? && !bookmarks.empty?
          fill_bookmarks_page
        end
      end

      def fill_bookmarks_page
        clear(bookmarks_container)

        bookmarks.to_a.reverse.each do |bookmark|
          bookmarks_container.insert(bookmark_button(bookmark).build, -1)
        end

        scroll_to_top(bookmarks_scroll)
        navigation_stack.push_by_tag("bookmarks")
      end

      def bookmark_button(bookmark)
        ChordPreviewButton.new(
          chord:       bookmark.chord,
          name:        bookmark.name,
          guitar_type: diagram.guitar_type,
          show_name:   true,
        ) { |chord, name| open_bookmark(chord, name) }
      end

      def open_bookmark(chord, name)
        diagram.chord = chord.dup
        entry.overwrite_text(ChordOps.prettify_chord_name(name))
        feedback_stack.visible_child_name = "chord-actions"
        refresh_star_toggle
        navigation_stack.pop
      end

      # ─── Startup and shutdown ───────────────────────────────────────────

      def load_stored_chord
        Bookmarks.load_current_chord.then do |bookmark|
          diagram.chord = bookmark.chord
          entry.overwrite_text(bookmark.name)

          unless bookmark.chord == EMPTY_CHORD
            feedback_stack.visible_child_name = "chord-actions"
          end

          refresh_star_toggle
        end
      end

      def on_close_request
        settings.remember(window)
        Bookmarks.save_current_chord(current_bookmark)
        false
      end

      # ─── Helpers ────────────────────────────────────────────────────────

      def on_chord_view? = navigation_stack.visible_page&.tag == "chord-view"

      def clear(container)
        until container.first_child.nil?
          container.remove(container.first_child)
        end
      end

      def scroll_to_top(scroll)
        scroll.vadjustment.value = scroll.vadjustment.lower
      end
  end
end
