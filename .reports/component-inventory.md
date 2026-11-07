# Fretboard component inventory

Upstream: `origin/main` (Rust/gtk-rs, GtkBuilder/blueprint templates under
`src/widgets/*.blp` + `*.rs`). Port: `ruby` branch, `lib/fretboard/*.rb`.

Order follows how a user meets the app: application bootstrap, main window
and its pages, then supporting dialogs/widgets, then non-widget logic.

| # | Upstream file(s) | Port file | Kind | Exists on `ruby`? |
|---|---|---|---|---|
| 1 | `src/main.rs` | `lib/fretboard.rb` (+ `exe/fretboard`) | app bootstrap (gresource load, gettext init, app run) | Yes |
| 2 | `src/application.rs` | `lib/fretboard/application.rb` | `Adw.Application` subclass — unit for `app.quit` action and all `app.*`/`win.*` accelerators (`<primary>q`, `<Ctrl>W`, `<Ctrl>E`, `<Ctrl>L`, `<Alt>Return`, `<Ctrl>D`, `<Ctrl><Alt>D`) | Yes |
| 3 | `src/widgets/window.rs` + `src/widgets/window.blp` | `lib/fretboard/window.rb` | main window (`Adw.ApplicationWindow`) — `Adw.NavigationView` with 3 pages (chord-view, more-variants, bookmarks), header bar, feedback `Gtk.Stack`, installs `win.empty-chord`, `win.chord-view`, `win.focus-entry`, `win.more-variants`, `win.bookmarks`, `win.bookmark-chord`, `win.about`, property-action `win.set-handedness` | Yes |
| 4 | `src/widgets/window.blp` `menu primary_menu { }` | `lib/fretboard/primary_menu.rb` | menu model — 3 sections: guitar-type radio (`win.set-handedness` targets `right-handed`/`left-handed`), `win.empty-chord`, `app.shortcuts` + `win.about` | Yes |
| 5 | `src/widgets/window.rs` (`Bookmark` struct, `add_bookmark`/`remove_bookmark`/`save_bookmarks`/`load_bookmarks`/bookmarks FlowBox population in `show_bookmarks`) | `lib/fretboard/bookmarks.rb` | bookmark storage + the bookmarks-page `Gtk.FlowBox` population (one `FretboardChordPreview` + title label + flat button per bookmark, reverse order) | Yes |
| 6 | `src/widgets/window.rs` (`show_about_dialog`) | `lib/fretboard/about_dialog.rb` | `Adw.AboutDialog` built from metainfo, with donate link and "other app" (Keypunch) entry | Yes |
| 7 | `data/resources/shortcuts-dialog.ui` (standalone GtkBuilder object, no backing `.rs`) | `lib/fretboard/shortcuts_dialog.rb` | `Adw.ShortcutsDialog`, 3 sections (General / Bookmarks / General actions), several items bound by `action-name` | Yes |
| 8 | `src/widgets/chord_diagram.rs` + `.blp` | `lib/fretboard/chord_diagram.rb` | `$FretboardChordDiagram` — fretboard grid, `top_row` toggle row, barre overlay `Gtk.Stack` (6 states), embeds `$FretboardBarreSpin`; fires `user-changed-chord` | Yes |
| 9 | `src/widgets/barre_spin.rs` + `.blp` | `lib/fretboard/barre_spin.rb` | `$FretboardBarreSpin` — vertical box, `decrement_button`/`increment_button` (flat, up/down icons) + label | Yes |
| 10 | `src/widgets/chord_diagram_toggle.rs` + `.blp` | `lib/fretboard/chord_diagram_toggle.rb` | `$FretboardChordDiagramToggle` — one flat `Gtk.ToggleButton`, used per fret/string dot in the grid (repeater, built from `chord_diagram.rb`) | Yes |
| 11 | `src/widgets/chord_diagram_top_toggle.rs` + `.blp` | `lib/fretboard/chord_diagram_top_toggle.rb` | `$FretboardChordDiagramTopToggle` — flat `Gtk.ToggleButton` + `Gtk.Overlay`'d icon `Gtk.Stack` (off/open/muted states for the open-string row) | Yes |
| 12 | `src/widgets/chord_name_entry.rs` + `.blp` | `lib/fretboard/chord_name_entry.rb` | `$FretboardChordNameEntry` — `Gtk.Entry` + overlaid `Gtk.Revealer`/`Gtk.Stack` (confirm button / enharmonic button, both flat+dimmed); fires `enharmonic-clicked` | Yes |
| 13 | `src/widgets/chord_preview.rs` + `.blp` | `lib/fretboard/chord_preview.rb` | `$FretboardChordPreview` — small read-only diagram (own `top_row`, barre overlay stack, `dots_grid`, `neck_position_label` with `title-3`) | Yes |
| 14 | `src/widgets/window.rs` (inline button-building closures in `more_variants` / `show_bookmarks`: `Gtk.Button.flat.fretboard-chord-preview-button` wrapping a `FretboardChordPreview`, `connect_clicked`) | `lib/fretboard/chord_preview_button.rb` | shared factory for the clickable preview-button used by both the variants `Gtk.FlowBox` and the bookmarks `Gtk.FlowBox` (two call sites) | Yes |
| 15 | `src/chord_name_algorithm.rs` | `lib/fretboard/chord_name_algorithm.rb` | pure logic — chord-name calculation from fret positions | Yes |
| 16 | `src/chord_ops.rs` | `lib/fretboard/chord_ops.rb` | pure logic — chord-name prettify/parse helpers | Yes |
| 17 | `src/database.rs` + `data/chords.txt` | `lib/fretboard/database.rb` | chord database (name ⇄ fret-position lookup) | Yes |
| 18 | `data/dev.bragefuglseth.Fretboard.gschema.xml` | `lib/fretboard/settings.rb` | GSettings wrapper — `window-width`, `window-height`, `is-maximized`, `handedness` (bound to `win.handedness` property) | Yes |
| 19 | `data/resources/style.css` | `lib/fretboard/style.rb` | stylesheet loader — CSS classes referenced across the port: `devel`, `dimmed`, `fretboard-star-toggle`, `fretboard-chord-preview-button`, `no-hover-active`, `fretboard-chord-name-entry`, `open`, `flat`, `title-3`, `card`-family classes from Adwaita | Yes |
| 20 | gettext setup in `src/main.rs` (`bindtextdomain`/`textdomain`) + `po/*.po`, `po/POTFILES.in` | `lib/fretboard/i18n.rb` | translation bootstrap (gettext binding for the Ruby runtime) | Yes |
| — | `po/LINGUAS`, `po/*.po` (41 locales) | n/a — translation catalogue, not a widget | n/a | out of scope for this component survey; see `translation-parity` skill |
| — | `data/dev.bragefuglseth.Fretboard.gschema.xml` as a GSettings *schema* (compiled `.gschema.xml` installed alongside the port) | checked separately — is the schema itself shipped/compiled for the Ruby app, not just wrapped in `settings.rb`? | config | **needs verification** — not confirmed in this survey; `settings.rb` existing does not by itself prove the schema file ships with the gem/app bundle |

## Notes / things to verify in a follow-up parity pass

- Every upstream widget file has a same-named `lib/fretboard/*.rb` counterpart, and every upstream widget has a counterpart file that already has a non-trivial line count (42–634 lines), so **no component in this unit list is structurally missing** on `ruby`. This survey did **not** verify widget-level parity (CSS classes, signal names, action names matching one-for-one) — that is the job of the `component-parity` skill, not this inventory.
- `src/widgets/window.rs` is one upstream file that the port deliberately fans out into five port files (`window.rb`, `primary_menu.rb`, `bookmarks.rb`, `about_dialog.rb`, `chord_preview_button.rb`). This matches the house style's preference for small memoized-widget files; parity still has to be checked against the *union* of all five, not against `window.rb` alone.
- `data/resources/shortcuts-dialog.ui` has no backing Rust source upstream (it is a standalone GtkBuilder object loaded directly) — `shortcuts_dialog.rb` is its port-side home, confirmed present.
- Icons (`data/resources/icons/scalable/actions/*.svg`), barre overlay assets (`data/resources/assets/barre-*.svg`, `prv-barre-*.svg`), and the app icon set are referenced by `chord_diagram.rb`/`chord_preview.rb`/`barre_spin.rb` but asset-file parity (do the port's resource paths resolve to equivalents of all of these) was not checked here.
- GResource manifest (`data/fretboard.gresource.xml.in`) was not diffed against whatever resource-loading `lib/fretboard.rb`/`style.rb` do — flagged for the parity pass.
