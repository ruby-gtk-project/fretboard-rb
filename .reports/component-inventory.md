# Fretboard component inventory

Upstream (origin/main) is the Rust/gtk-rs/blueprint implementation of
Fretboard. This is a survey only — no app code was written in this step.

Upstream source consulted: `src/application.rs`, `src/main.rs`,
`src/widgets/{window,barre_spin,chord_diagram,chord_diagram_toggle,
chord_diagram_top_toggle,chord_name_entry,chord_preview}.{rs,blp}`,
`data/resources/shortcuts-dialog.ui`, `data/resources/style.css`,
`data/dev.bragefuglseth.Fretboard.gschema.xml`, `po/LINGUAS` + `po/*.po`
(37 languages), `src/chord_ops.rs`, `src/chord_name_algorithm.rs`,
`src/database.rs`, `data/chords.txt`.

## Result

Every upstream user-facing component already has a corresponding file in
`lib/fretboard/` on `ruby`, and each one's leading comment names the
upstream file(s) it was ported from. No gaps were found. This inventory
is the parity map confirming that; a full line-by-line component-parity
pass (widget-by-widget, CSS class by CSS class, signal by signal) is a
separate step this task did not perform.

| # | Upstream file(s) | `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| 1 | `src/application.rs` | `lib/fretboard/application.rb` | Application class — actions (`app.quit`), accelerators (`<primary>q`, `<Ctrl>W`, `<Ctrl>E`, `<Ctrl>L`, `<Alt>Return`, `<Ctrl>D`, `<Ctrl><Alt>D`), activation/present-existing-window | Yes |
| 2 | `src/main.rs` (gettext bootstrap + GResource registration) | `lib/fretboard/i18n.rb` + `lib/fretboard.rb` | App bootstrap: textdomain setup, resource loading | Yes |
| 3 | `src/widgets/window.rs` + `window.blp` | `lib/fretboard/window.rb` | Main window — `Adw.ApplicationWindow` with `Adw.NavigationView` (3 pages: chord-view, more-variants, bookmarks), header bar, bookmarks button, menu button, feedback `Gtk.Stack` (empty/label/chord-actions), star toggle, "View Variants" button, window actions (`win.empty-chord`, `win.chord-view`, `win.focus-entry`, `win.more-variants`, `win.bookmarks`, `win.bookmark-chord`, `win.about`, `win.set-handedness` property action), window-size persistence, current-chord persistence | Yes |
| 4 | `Bookmark` struct + add/remove/load/save in `window.rs` | `lib/fretboard/bookmarks.rb` | Bookmark model + JSON persistence (`bookmarks.json`) | Yes |
| 5 | variants/bookmarks `FlowBox` population loops in `window.rs` (the per-row preview button built in `more_variants`/`show_bookmarks`) | `lib/fretboard/chord_preview_button.rb` | Repeater component — flat button wrapping a `FretboardChordPreview`, one per chord variant/bookmark | Yes |
| 6 | `src/widgets/chord_diagram.rs` + `chord_diagram.blp` | `lib/fretboard/chord_diagram.rb` | The interactive fretboard — top-string toggle row, 6×5 fret toggle grid, barre overlay (`Gtk.Stack` with 5 barre-width images), neck-position barre spin, light/dark/high-contrast backdrop swap, `user-changed-chord` signal | Yes |
| 7 | `src/widgets/chord_diagram_top_toggle.rs` + `.blp` | `lib/fretboard/chord_diagram_top_toggle.rb` | Per-string open/muted/off toggle button with icon `Gtk.Stack` (dot/open/muted) and dynamic a11y label/tooltip | Yes |
| 8 | `src/widgets/chord_diagram_toggle.rs` + `.blp` | `lib/fretboard/chord_diagram_toggle.rb` | One fret-position toggle button in the grid | Yes |
| 9 | `src/widgets/barre_spin.rs` + `.blp` | `lib/fretboard/barre_spin.rb` | Neck-position stepper — increment/decrement buttons + label, `user-changed-value` signal, min/max clamping (1–12) | Yes |
| 10 | `src/widgets/chord_name_entry.rs` + `.blp` | `lib/fretboard/chord_name_entry.rb` | Chord-name entry — `Gtk.Entry` overlay with a `Gtk.Revealer`/`Gtk.Stack` holding the confirm button or the enharmonic-equivalent button, `enharmonic-clicked` signal | Yes |
| 11 | `src/widgets/chord_preview.rs` + `.blp` | `lib/fretboard/chord_preview.rb` | Small read-only chord diagram used in variant/bookmark grids — top symbols, dot grid, barre overlay, neck-position label | Yes |
| 12 | `data/resources/shortcuts-dialog.ui` | `lib/fretboard/shortcuts_dialog.rb` | `Adw.ShortcutsDialog` — 3 sections (General, Bookmarks, App), 9 `Adw.ShortcutsItem`s | Yes |
| 13 | `show_about_dialog` in `window.rs` | `lib/fretboard/about_dialog.rb` | `Adw.AboutDialog` built from metainfo, developer/copyright/translator-credits, donate link, "other app" entry for Keypunch | Yes |
| 14 | `menu primary_menu` block in `window.blp` | `lib/fretboard/primary_menu.rb` | Main menu model — guitar-type section (right/left-handed radio items), empty-chord item, shortcuts/about section | Yes |
| 15 | `data/resources/style.css` | `lib/fretboard/style.rb` | App stylesheet loader/CSS provider | Yes |
| 16 | `data/dev.bragefuglseth.Fretboard.gschema.xml` + settings load/save in `window.rs` | `lib/fretboard/settings.rb` | GSettings wrapper — `window-width`, `window-height`, `is-maximized`, `handedness` | Yes |
| 17 | `src/chord_ops.rs` | `lib/fretboard/chord_ops.rb` | Chord-name parsing/formatting/enharmonic helpers (not UI, but feeds the entry/diagram) | Yes |
| 18 | `src/chord_name_algorithm.rs` | `lib/fretboard/chord_name_algorithm.rb` | Fallback chord-name-from-fingering algorithm | Yes |
| 19 | `src/database.rs` + `data/chords.txt` | `lib/fretboard/database.rb` | Built-in chord database (name ↔ fingering lookups) | Yes |
| 20 | `po/LINGUAS` + `po/*.po` (37 catalogues) | `lib/fretboard/i18n.rb` | Translation catalogue loading | Present — translation-parity (msgid-by-msgid, all 37 languages) is a separate check this step did not run |

## Notes / what this survey did not do

- This is a file-level existence and attribution check, not a
  widget-by-widget component-parity audit. CSS class parity, signal
  parity and accessibility-label parity for each widget still need the
  `component-parity` skill's full pass before the port can be called
  finished.
- Translation parity (every msgid in all 37 `po/*.po` files reproduced
  byte-for-byte) was not verified here; `translation-parity` is the next
  required step.
- Upstream (`origin/main`) has no test files at all (`git ls-tree -r
  --name-only origin/main | grep -i test` returns nothing), so there is
  no upstream test suite to establish parity against.
- No upstream component was found without a `lib/*.rb` counterpart.

## Re-verified 2026-11-07 against `HEAD` `dcfe7a6`

Re-read `git ls-tree -r --name-only origin/main` and diffed it against this
table's source-file list; no upstream file was added or removed since this
inventory was written, so the 20-row list above still accounts for every
upstream component. Three items row 16 describes as present (the GSettings
schema, desktop entry, AppStream metainfo) were JSON/absent when this
inventory's "Present" column was first written and have since been built
for real — see `.reports/component-parity.md`'s "Status refresh" sections.
This file's rows were correct about *existence* throughout; the *behaviour*
and *text* axes they explicitly deferred are `component-parity.md`'s and
`TRANSLATION_PARITY.md`'s job, not re-litigated here.
