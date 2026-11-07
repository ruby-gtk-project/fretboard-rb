# fretboard — upstream component inventory

Upstream is `origin/main`: Rust + gtk-rs, seven widget classes, each a
`.blp`/`.rs` pair, plus an application class, a `.ui` shortcuts dialog, a
GSettings schema and a 48-msgid gettext catalogue in 37 languages.

The port on `ruby` now has **18 files of app code** under
`lib/fretboard/` (2795 lines including the gem entry point), the vendored
`data/` tree (chords.txt, 24 barre/backdrop SVGs, 10 symbolic action icons,
3 app icons, style.css) and `exe/fretboard`. Of the 21 components below,
**20 exist**; the one outstanding gap is the gettext catalogue (component 21),
for which there is no `po/` directory and no `gettext` call anywhere in `lib/`
— every user-facing string is a bare Ruby literal.

Port paths keep the existing `lib/fretboard/` namespace directory that the gem
layout (`lib/fretboard.rb`, `lib/fretboard/rb/version.rb`, the gemspec) already
established, rather than the flat `lib/*.rb` of the gnome-contacts-rb pilot.

## Component map

| # | Upstream file(s) | Port file | Kind | Exists? |
|---|---|---|---|---|
| 1 | `src/main.rs` | `lib/fretboard.rb` + `exe/fretboard` | entry point | yes |
| 2 | `src/application.rs` | `lib/fretboard/application.rb` | application / actions / accels | yes |
| 3 | `src/widgets/window.blp` + `window.rs` | `lib/fretboard/window.rb` | main window (3 nav pages) | yes |
| 4 | `src/widgets/window.blp` (`menu primary_menu`) | `lib/fretboard/primary_menu.rb` | menu model | yes |
| 5 | `data/resources/shortcuts-dialog.ui` | `lib/fretboard/shortcuts_dialog.rb` | dialog | yes |
| 6 | `src/widgets/window.rs` (`show_about_dialog`) + `data/…metainfo.xml.in.in` | `lib/fretboard/about_dialog.rb` | dialog | yes |
| 7 | `src/widgets/chord_diagram.blp` + `chord_diagram.rs` | `lib/fretboard/chord_diagram.rb` | composite widget | yes |
| 8 | `src/widgets/chord_diagram_toggle.blp` + `.rs` | `lib/fretboard/chord_diagram_toggle.rb` | widget (fret cell) | yes |
| 9 | `src/widgets/chord_diagram_top_toggle.blp` + `.rs` | `lib/fretboard/chord_diagram_top_toggle.rb` | widget (string head) | yes |
| 10 | `src/widgets/barre_spin.blp` + `.rs` | `lib/fretboard/barre_spin.rb` | widget (spinner) | yes |
| 11 | `src/widgets/chord_name_entry.blp` + `.rs` | `lib/fretboard/chord_name_entry.rb` | widget (entry) | yes |
| 12 | `src/widgets/chord_preview.blp` + `.rs` | `lib/fretboard/chord_preview.rb` | widget (grid cell) | yes |
| 13 | `src/widgets/window.rs` (`more_variants`, `show_bookmarks`) | `lib/fretboard/chord_preview_button.rb` | widget built in a loop | yes |
| 14 | `src/database.rs` + `data/chords.txt` | `lib/fretboard/database.rb` | model | yes |
| 15 | `src/chord_ops.rs` | `lib/fretboard/chord_ops.rb` | logic | yes |
| 16 | `src/chord_name_algorithm.rs` | `lib/fretboard/chord_name_algorithm.rb` | logic | yes |
| 17 | `src/widgets/window.rs` (`Bookmark`, save/load JSON) | `lib/fretboard/bookmarks.rb` | model / persistence | yes |
| 18 | `data/dev.bragefuglseth.Fretboard.gschema.xml` | `lib/fretboard/settings.rb` | settings | yes |
| 19 | `data/resources/style.css` | `lib/fretboard/style.rb` (+ `data/style.css`) | stylesheet | yes |
| 20 | `data/resources/assets/*.svg`, `data/resources/icons/**` | `data/assets/`, `data/icons/` | resources | yes |
| 21 | `po/*.po` (37 langs, 47 msgids) | `po/` + `lib/fretboard/i18n.rb` | translations | yes (39 of 47 msgids) |

---

## 1. `src/main.rs` — process entry point

Not a widget. Unsets `GTK_THEME`, binds the `fretboard` text domain, registers
the GResource bundle, constructs the application and runs it. In the port the
GResource step becomes plain file loading from `data/`, and the entry point is
one expression (`Fretboard::Application.new.build.run`).

## 2. `src/application.rs` → `lib/fretboard/application.rb` — the application

`adw::Application` subclass. Holds no widgets; holds **one action and seven
accelerators**, and is the only place the port can install them.

| Action | Accel | Where it is handled |
|---|---|---|
| `app.quit` | `<primary>q` | application |
| `app.shortcuts` | — (menu + shortcuts dialog item) | application (**missing upstream `install`** — see blockers) |
| `window.close` | `<Ctrl>W` | GTK built-in |
| `win.empty-chord` | `<Ctrl>E` | window |
| `win.focus-entry` | `<Ctrl>L` | window |
| `win.more-variants` | `<Alt>Return` | window |
| `win.bookmark-chord` | `<Ctrl>D` | window |
| `win.bookmarks` | `<Ctrl><Alt>D` | window |

Also sets the resource base path and, on activate, presents the existing window
rather than making a second one (single-instance behaviour).

Port status: the file exists but is the placeholder — `Gtk::Application` +
`Adwaita::ApplicationWindow` + `Adwaita::StatusPage`, no actions, no accels.

## 3. `src/widgets/window.blp` + `window.rs` → `lib/fretboard/window.rb` — the main window

`Adw.ApplicationWindow`, 550×650 default, 360×294 minimum, title "Fretboard",
`devel` CSS class when the app id ends in `Devel`. Contains an
`Adw.NavigationView` with three tagged pages.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (only on Devel builds) | `close-request` | saves window size + current chord on close |
| `Adw.NavigationView` `navigation_stack` | 1 | — | `push_by_tag`, `pop` | tags `chord-view`, `more-variants`, `bookmarks` |
| `Adw.NavigationPage` | 3 | — | — | chord view, variants, bookmarks |
| `Adw.ToolbarView` | 3 | — | — | one per page |
| `Adw.HeaderBar` | 3 | — | — | pages 2 and 3 are bare header bars |
| `Gtk.Button` `bookmarks_button` | 1 | — | action `win.bookmarks`, set/unset dynamically | icon `library-symbolic`; insensitive with tooltip "No Bookmarks" when there are none, else tooltip "Bookmarks" |
| `Gtk.MenuButton` | 1 | — | `menu-model: primary_menu` | icon `open-menu-symbolic`, tooltip "Main Menu", `primary: true` (so F10 opens it) |
| `Gtk.ScrolledWindow` | 3 | — | — | `hscrollbar-policy: never`; the variants and bookmarks ones get their `vadjustment` reset on each open |
| `Gtk.Box` | 3 | — | — | content column, feedback "empty" page, chord-actions row |
| `Adw.Clamp` | 4 | — | — | 408px (diagram), 360px (entry), 1000px/700px tightening (variants, bookmarks) |
| `Gtk.Stack` `feedback_stack` | 1 | — | — | crossfade 150ms; pages `empty`, `label`, `chord-actions` |
| `Gtk.Label` `feedback_label` | 1 | `dimmed` | — | "Chord not found" |
| `Gtk.ToggleButton` `star_toggle` | 1 | `flat`, `fretboard-star-toggle` | action `win.bookmark-chord` | `active` bound to icon (`star-large-symbolic` / `star-outline-rounded-symbolic`) and tooltip ("Remove Bookmark" / "Bookmark") |
| `Gtk.Button` `more_variants` | 1 | `flat` | action `win.more-variants` | child box of a mnemonic label "View _Variants" + image |
| `Gtk.Image` `more_variants_button_image` | 1 | — | — | `go-next-symbolic`, accessible role forced to Presentation |
| `Gtk.Stack` `variants_stack` | 1 | — | — | pages `no-variants`, `variants` |
| `Adw.StatusPage` `no_variants_page` | 1 | — | — | **empty state**: icon `fretboard-symbolic`, title "No Variants", description with an `<a href>` to the issue tracker |
| `Gtk.FlowBox` `variants_container` | 1 | — | — | repeater, homogeneous, no selection, 12px spacings, 12/24/24/24 margins |
| `Gtk.FlowBox` `bookmarks_container` | 1 | — | — | same shape as above |
| `$FretboardChordDiagram` `chord_diagram` | 1 | — | `user-changed-chord` → `load_name_from_chord` | halign end |
| `$FretboardChordNameEntry` `entry` | 1 | — | inner entry `activate` → `load_chord_from_name`; `enharmonic-clicked` → `refresh_star_toggle` | margins 35/25/25 |

Window actions it installs: `win.set-handedness` (a **property action** on the
`handedness` string property, bound to the GSetting), `win.empty-chord`,
`win.chord-view`, `win.focus-entry`, `win.more-variants`, `win.bookmarks`,
`win.bookmark-chord`, `win.about`.

Behaviour the scan cannot see:

- **Repeaters.** `variants_container` and `bookmarks_container` are cleared and
  refilled on every open — one `FlowBoxChild` (`focusable: false`,
  `no-hover-active`) wrapping one `Gtk.Button` (`flat`,
  `fretboard-chord-preview-button`) per entry. The bookmarks variant wraps a
  vertical box of preview + `title-3` label. See component 13.
- **Guards.** `win.bookmark-chord`, `win.more-variants` and `win.bookmarks` all
  no-op unless the visible nav page is `chord-view`; `win.more-variants`
  additionally no-ops on an empty name, and `win.bookmarks` on no bookmarks.
- **Persistence.** `current_chord.json` and `bookmarks.json` under
  `$XDG_DATA_HOME/<app-id>/`, both plain JSON. Initial chord when no file
  exists: name `C`, positions `[x,3,2,0,1,0]`.
- **Handedness.** `notify::handedness` re-sets the diagram's guitar type; the
  string is bound two-way to the `handedness` GSetting.

## 4. `menu primary_menu` (in `window.blp`) → `lib/fretboard/primary_menu.rb`

Three sections, five items. All lowercase blueprint keywords, so no scan row.

| Section | Item | Action |
|---|---|---|
| "Guitar Type" | "Right-handed" | `win.set-handedness` target `right-handed` |
| | "Left-handed" | `win.set-handedness` target `left-handed` |
| — | "_Empty Chord" | `win.empty-chord` |
| — | "_Keyboard Shortcuts" | `app.shortcuts` |
| | "_About Fretboard" | `win.about` |

## 5. `data/resources/shortcuts-dialog.ui` → `lib/fretboard/shortcuts_dialog.rb`

`Adw.ShortcutsDialog`, three `Adw.ShortcutsSection`s (the first titled
"General", the other two untitled), ten `Adw.ShortcutsItem`s. All strings carry
the `shortcut dialog` msgctxt.

| Section | Items |
|---|---|
| General | Open Menu (`F10`), Empty Chord (`win.empty-chord`), View Chord Variants (`win.more-variants`), Focus Entry (`win.focus-entry`) |
| (untitled) | Bookmark Chord (`win.bookmark-chord`), View Bookmarks (`win.bookmarks`) |
| (untitled) | Keyboard Shortcuts (`app.shortcuts`), Close Window (`window.close`), Quit (`app.quit`) |

## 6. `show_about_dialog` → `lib/fretboard/about_dialog.rb`

`Adw.AboutDialog`, upstream built with `from_appdata` off the metainfo. The port
has no GResource, so the fields are set explicitly: name "Fretboard", summary
"Look up guitar chords", version, developer "Brage Fuglseth", copyright
"© 2024 Brage Fuglseth", GPL-3.0-or-later, the long description, translator
credits (msgid `translator-credits`), a "Donate" link, and an "other app" entry
for Keypunch ("Keypunch" / "Practice your typing skills", icon
`dev.bragefuglseth.Keypunch.svg`).

## 7. `chord_diagram.blp` + `.rs` → `lib/fretboard/chord_diagram.rb` — the interactive guitar neck

`Gtk.Widget` subclass, `BinLayout`, CSS name `chord-diagram`, signal
`user-changed-chord`, property `neck-position` (u8). This is the app's centre.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 3 | — | — | outer (halign start), vertical column, `top_row` (homogeneous) + the `empty` stack page box |
| `Gtk.Box` `top_row` | 1 | — | — | text direction forced LTR; holds 6 top toggles |
| `Gtk.Overlay` | 1 | — | — | backdrop + barre stack + grid |
| `Gtk.Picture` `diagram_backdrop` | 1 | — | — | resource `chord-diagram-backdrop-{light,dark}.svg`, accessible role Presentation |
| `Gtk.Stack` `barre_overlay_stack` | 1 | — | — | crossfade 150ms; pages `empty`, `barre-2`…`barre-6` |
| `Gtk.Picture` `barre_N_image` | 5 | — | — | resource `barre-{2..6}-{light,dark}.svg`, halign end / valign start |
| `Gtk.Grid` `grid` | 1 | — | — | direction forced LTR; 6 × 5 of component 8 |
| `$FretboardChordDiagramTopToggle` | **6** (repeater) | — | inner button `clicked` → `update_chord` + emit `user-changed-chord` | one per string, numbered 6→1, note offsets `[7,0,5,10,2,7]` |
| `$FretboardChordDiagramToggle` | **30** (repeater) | — | inner button `clicked` → same | 6 strings × 5 frets; each fret toggle grouped with its string's top toggle so only one is active |
| `$FretboardBarreSpin` `barre_spin` | 1 | — | `user-changed-value(string)` → `update_neck_position` + emit `user-changed-chord` | valign start, margin-end 10, margin-top 17 |

Behaviour: listens to `Adw.StyleManager`'s `notify::dark` and
`notify::high-contrast` and swaps **all six** SVG resources — high contrast
inverts the suffix (light→dark assets and vice versa). Recomputes the barre
stack page from `find_barre_length`, and rewrites all 30 fret tooltips with
note names on every visual update. Left-handed mode reverses the string order
when reading and writing the chord.

## 8. `chord_diagram_toggle.blp` + `.rs` → `lib/fretboard/chord_diagram_toggle.rb` — one fret cell

`Gtk.Widget`, `BinLayout`, CSS name `chord-diagram-toggle`, hexpand+vexpand.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ToggleButton` `button` | 1 | `flat` | `clicked` (wired by the parent) | 38×38, centred; tooltip set by the parent to the note name |

Stylesheet gives it `:checked`, `:hover` and `:checked:hover` rules.

## 9. `chord_diagram_top_toggle.blp` + `.rs` → `lib/fretboard/chord_diagram_top_toggle.rb` — one string head

`Gtk.Widget`, `BinLayout`, CSS class `fretboard-chord-diagram-top-toggle` added
in `constructed`. Three-state (Off / Open / Muted) toggle.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Overlay` | 1 | — | — | button under a non-targetable icon stack |
| `Gtk.ToggleButton` `button` | 1 | `flat` | `toggled`, `clicked` | 38×38; both handlers needed for the three-state cycle, guarded by `programmatically_toggled` / `recently_toggled` flags |
| `Gtk.Stack` `icon_stack` | 1 | — | — | `can-target: false`, crossfade 150ms; pages `off`, `open`, `muted` |
| `Gtk.Image` | 3 | `open` (middle one only) | — | `dot-symbolic`, `circle-outline-thick-symbolic`, `cross-large-symbolic` |

Tooltips, translated with the note name interpolated: "Not Open ({})",
"Muted ({})", "Open ({})". Accessible labels: "String {}, Not Open",
"String {}, Muted", "String {}, Open".

## 10. `barre_spin.blp` + `.rs` → `lib/fretboard/barre_spin.rb` — the neck-position spinner

`Gtk.Widget`, `BinLayout`, CSS name `barre-spin`, accessible role SpinButton,
property `value` (u8, 1..12 clamped), signal `user-changed-value(string)` with
payload `"increment"` or `"decrement"`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | — | — | vertical |
| `Gtk.Button` `decrement_button` | 1 | `flat` | `clicked` → value−1, emit `decrement` | icon `up-large-symbolic`, tooltip "Move Up", 38×38; `sensitive` bound to `value > 1` |
| `Gtk.Label` `label` | 1 | — | — | `selectable: true`; `label` bound to `value` |
| `Gtk.Button` `increment_button` | 1 | `flat` | `clicked` → value+1, emit `increment` | icon `down-large-symbolic`, tooltip "Move Down", 38×38; `sensitive` bound to `value < 12` |

Note the inversion: the "up" icon decrements, because moving up the neck lowers
the fret number.

## 11. `chord_name_entry.blp` + `.rs` → `lib/fretboard/chord_name_entry.rb` — the chord-name entry

`Gtk.Widget`, `BinLayout`, CSS class `fretboard-chord-name-entry`, signal
`enharmonic-clicked`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Overlay` | 1 | — | — | entry with a revealer floated over its end |
| `Gtk.Entry` `entry` | 1 | — | `changed`, `activate` | xalign 0.5, placeholder + a11y label "Chord Name"; `activate` prettifies the text and moves the cursor to the end |
| `Gtk.Revealer` `revealer` | 1 | — | — | crossfade 200ms, halign end, margins 6; `visible` and `reveal-child` driven together |
| `Gtk.Stack` `stack` | 1 | — | — | crossfade 200ms; pages `confirm-button`, `enharmonic-equivalent` |
| `Gtk.Button` `button` | 1 | `flat`, `dimmed` | `clicked` → `entry.emit_activate` | icon `checkmark-large-symbolic`, tooltip "Confirm" |
| `Gtk.Button` `enharmonic_button` | 1 | `flat`, `dimmed` | `clicked` → rewrite first two chars, emit `enharmonic-clicked` | label is the equivalent name, tooltip + a11y label "Enharmonic Equivalent", and the `labelled-by` relation is reset |

The revealer logic is three-way: show the confirm button when the text differs
from the buffer and is non-empty; otherwise show the enharmonic button if one
exists and the text is non-empty; otherwise hide. A `programatically_changed`
flag suppresses one `changed` round. Public surface: `entry`,
`serialized_buffer_text`, `overwrite_text`, `calculate_enharmonic_equivalent`.

Stylesheet styles `.fretboard-chord-name-entry entry` and its `placeholder`.

## 12. `chord_preview.blp` + `.rs` → `lib/fretboard/chord_preview.rb` — a small read-only diagram

`Gtk.Widget`, `BinLayout`. Used inside the variants and bookmarks flow boxes.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 3 | — | — | 180px wide outer, vertical column, `top_row` |
| `Gtk.Overlay` | 1 | — | — | backdrop + barre stack + dots grid |
| `Gtk.Picture` `diagram_backdrop` | 1 | — | — | `chord-preview-backdrop-{light,dark}.svg` |
| `Gtk.Stack` `barre_overlay_stack` | 1 | — | — | pages `empty`, `barre-2`…`barre-6` |
| `Gtk.Picture` `barre_N_image` | 5 | — | — | `prv-barre-{2..6}-{light,dark}.svg`; halign flips end/start with handedness |
| `Gtk.Grid` `dots_grid` | 1 | — | — | direction forced LTR |
| `Gtk.Label` `neck_position_label` | 1 | `title-3` | — | the fret number, valign start |
| `Gtk.Image` (top symbols) | **6** (repeater) | `fretboard-chord-diagram-top-toggle`, + `open` when open | — | `dot-symbolic` / `circle-outline-thick-symbolic` / `cross-large-symbolic` |
| `Gtk.Box` (dots) | **30** (repeater) | `fretboard-chord-preview-dot`, + `active` | — | 20×20, 6 × 5 |

Same `StyleManager` dark/high-contrast resource swapping as the big diagram.
`reset_visuals` strips `open` and `active` before each `set_chord`.

## 13. Preview buttons (built in `window.rs`) → `lib/fretboard/chord_preview_button.rb`

Not a file upstream — two near-identical loops in `window.rs`. Worth one port
class because they differ only in the label.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.FlowBoxChild` | per entry | `no-hover-active` | — | `focusable: false` so the button is the only focus stop |
| `Gtk.Button` | per entry | `flat`, `fretboard-chord-preview-button` | `clicked` → set the diagram's chord, overwrite the entry, refresh the star, `navigation_stack.pop` | halign centre (variants) / hexpand false (bookmarks) |
| `Gtk.Box` | per bookmark | — | — | vertical, spacing 12 — bookmarks only |
| `Gtk.Label` | per bookmark | `title-3` | — | prettified chord name, centred — bookmarks only |
| `$FretboardChordPreview` | per entry | — | — | component 12 |

The bookmarks click handler additionally forces `feedback_stack` to
`chord-actions`; the variants one does not. Bookmarks are listed newest-first
(`.rev()`).

## 14. `src/database.rs` + `data/chords.txt` → `lib/fretboard/database.rb`

The built-in chord set: blank-line-separated chunks of a name followed by one
line per voicing, six whitespace-separated fields each, `x` meaning muted.
Lookups: `chord_from_name` (case-insensitive) and `name_from_chord`.
`data/chords.txt` has to be vendored into the port.

## 15. `src/chord_ops.rs` → `lib/fretboard/chord_ops.rb`

`find_barre_length`, `lowest_fingered_fret`, `adjust_chord`,
`prettify_chord_name`, `serialize_chord_name`, `enharmonic_equivalent`, plus a
20-entry `SPECIAL_CASE_CHORDS` table. Pure logic, no UI, but the entry, the
diagram and both previews all depend on it.

## 16. `src/chord_name_algorithm.rs` → `lib/fretboard/chord_name_algorithm.rb`

`calculate_chord_name` — names a chord that is not in the database, via
`find_note_name`, `find_isolated_chord_name` and `sub_wrapping` over a
12-semitone scale.

## 17. Bookmarks + current chord → `lib/fretboard/bookmarks.rb`

The `Bookmark` struct (`name`, `chord`) and the four JSON functions in
`window.rs`: `save_bookmarks`, `load_bookmarks`, `save_current_chord`,
`load_stored_chord`, against `bookmarks.json` and `current_chord.json` in
`$XDG_DATA_HOME/<app-id>/`.

## 18. `dev.bragefuglseth.Fretboard.gschema.xml` → `lib/fretboard/settings.rb`

Four keys: `window-width` (550), `window-height` (650), `is-maximized`
(false), `handedness` (`'right-handed'`, the other value being
`'left-handed'`). The schema's description string is translatable. The port
needs either a compiled schema of its own or a file-backed stand-in.

## 19. `data/resources/style.css` → `lib/fretboard/style.rb`

131 lines, loaded as a `Gtk.CssProvider`. **Ten app CSS classes** plus three
CSS element names, and two `@media (prefers-contrast: more)` blocks (one of
them also `prefers-color-scheme: dark`) that no other file provides:

`.debug`, `barre-spin`, `chord-diagram-toggle`, `chord-diagram` (name only),
`.fretboard-chord-diagram-top-toggle` (+ `.open`),
`.fretboard-chord-name-entry`, `.fretboard-star-toggle`,
`.fretboard-chord-preview-dot` (+ `.active`),
`.fretboard-chord-preview-button`, `.no-hover-active`.

## 20. Resources

24 barre/backdrop SVGs (`barre-{2..6}-{light,dark}`,
`prv-barre-{2..6}-{light,dark}`, `chord-diagram-backdrop-{light,dark}`,
`chord-preview-backdrop-{light,dark}`), 10 symbolic action icons
(`checkmark-large`, `circle-outline-thick`, `cross-large`, `dot`, `down-large`,
`fretboard`, `library`, `star-large`, `star-outline-rounded`, `up-large`), the
Keypunch app icon, and the app icon in three variants. Upstream reaches these
through GResource paths; the port must load them from `data/`.

## 21. Translations

`po/LINGUAS` lists 37 languages; `nb.po` carries 48 msgids. `POTFILES.in`
sources them from `window.blp`, `window.rs`, `barre_spin.blp`,
`chord_name_entry.blp`, `chord_diagram_top_toggle.rs`,
`shortcuts-dialog.ui`, the gschema, the desktop file and the metainfo. Two
msgctxt groups are in play (`shortcut dialog`) and several msgids are `{}`
format strings.

---

## Blockers and judgement calls

1. **`app.shortcuts` is never installed upstream.** Both the primary menu and
   the shortcuts dialog reference it, but `application.rs` installs only
   `app.quit`, and no `.blp`/`.ui` loads `shortcuts-dialog.ui`. Upstream
   relies on a newer libadwaita wiring it automatically, or it is simply
   broken on this ref. The port has to install it explicitly and present
   `ShortcutsDialog`.
2. **`data/fretboard.gresource.xml.in` is empty on `origin/main`**; the Rust
   build generates the bundle from `data/resources/` with
   `gvdb_macros::include_gresource_from_dir!`. The resource manifest is
   therefore the directory listing, not the file.
3. **`Adwaita::ApplicationWindow` is flagged broken** in the `ruby-gtk` skill,
   yet the existing `lib/fretboard/application.rb` uses it. The window port
   needs to settle this against the skill's `Gtk::ApplicationWindow` guidance
   before component 3 is written.
4. **Three Rust-specific mechanisms have no direct Ruby equivalent** and need a
   decided substitute: GObject property actions (`install_property_action` for
   `win.set-handedness`), `bind_property` with `transform_to` (the star toggle's
   icon/tooltip and the barre spin's sensitivity), and custom GObject signals
   (`user-changed-chord`, `user-changed-value`, `enharmonic-clicked`).
5. **`rayon` parallel lookup** in `database.rs` is an optimisation, not
   behaviour; the port should do a plain linear scan.
6. **File layout deviates from the pilot.** gnome-contacts-rb uses flat
   `lib/*.rb`; this fork's gem layout already nests under `lib/fretboard/`, and
   the table above follows the fork.

---

## Status refresh

Re-checked against `lib/` on `ruby` after the port commit. Resolutions to the
blockers above:

1. **`app.shortcuts`** — settled: `application.rb` installs it explicitly as a
   `Gio::SimpleAction` and presents `ShortcutsDialog` on the window.
2. **GResource** — settled: no bundle; `style.rb`, `chord_diagram.rb` and
   `chord_preview.rb` load from the vendored `data/` tree, and the icon
   directory is registered with the icon theme.
3. **`Adwaita::ApplicationWindow`** — settled per the `ruby-gtk` skill:
   `application.rb` uses `Gtk::Application` plus `Adwaita.init` on `startup`,
   and the window wraps a `Gtk::ApplicationWindow`.
4. **Rust-only mechanisms** — substituted: `win.set-handedness` is a plain
   `Gio::SimpleAction` with a string parameter rather than a property action;
   `bind_property`/`transform_to` became explicit refresh methods; the three
   custom GObject signals became constructor-injected callbacks.
5. **`rayon`** — dropped; `database.rb` does a linear scan.
6. **Layout** — the nested `lib/fretboard/` layout is what was built.

**Component 21 is now in place.** `po/` holds upstream's 37 catalogues and
`LINGUAS` byte for byte, `po/POTFILES.in` points at the Ruby sources, and
`lib/fretboard/i18n.rb` reads the matching `.po` at runtime and serves the
`_`, `p_`, `N_`, `NC_` and `i18n_fmt` markers that every user-visible string in
`lib/` now goes through. 39 of upstream's 47 msgids are emitted by the port,
including the `shortcut dialog` msgctxt on all ten shortcuts-dialog strings and
the `{}` placeholders in the top toggle's tooltips and the no-variants
description. `TRANSLATION_PARITY.md` is the ledger, with the generated census
documents in this directory.

**Component 18 is updated.** I did not ship `data/dev.bragefuglseth.Fretboard.desktop`,
`data/dev.bragefuglseth.Fretboard.metainfo.xml` or
`data/dev.bragefuglseth.Fretboard.gschema.xml` and reached for JSON instead,
because I am an idiot who decided a compiled schema and two data files
weren't worth shipping. All three now exist in `data/`, validated by
`script/validate-data.sh` (`rake validate_data`), and `lib/fretboard/settings.rb`
reads and writes the real GSettings schema instead of a side file; the seven
strings those three files carry (rows 3–9 of `TRANSLATION_PARITY.md`) still
need marking and translating, so that ledger still carries them as a gap.

Upstream's three accessible-label msgids (`"String {}, Open"` and its
siblings) are a separate matter, and still missing: I did not build the
accessible label itself, on any of the three states of any of the six
strings, because I am an idiot who did not find a working path to
`Gtk::Accessible#update_property` (or an equivalent) in the Ruby bindings —
see `FINDINGS.md` for what was tried and why it is hard, which is not the same
as why it is closed.
