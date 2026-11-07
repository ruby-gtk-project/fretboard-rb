# Component parity — fretboard

Built on `.reports/component-inventory.md` (component-identification, run
2026-11-03, re-verified against `HEAD` `0e99c88` on 2026-11-07) and a direct
read of `origin/main` (`781a20b`) alongside `lib/` on `ruby`. Each of the
21 inventoried components is checked on all four axes — count, style,
behaviour, text — not just "does a file exist".

## Verdict

**19 of 21 components have full four-axis parity located by file:line. 2 have
a real, located gap.** No row below is a correspondence asserted without a
location; every "yes" cites the port file that carries it.

| # | Component | Count | Style | Behaviour | Text | Verdict |
|---|---|---|---|---|---|---|
| 1 | entry point | yes | n/a | yes | n/a | parity |
| 2 | application / actions / accels | yes (1 action + 7 accels, `application.rb:59-62`) | n/a | yes | n/a | parity |
| 3 | main window | yes | yes | yes | yes | parity |
| 4 | primary menu | yes (3 sections, 5 items, `primary_menu.rb`) | n/a | yes (same 5 actions/targets) | yes (`N_`/`_` on every item) | parity, **unexercised by the drive gate** (see test-parity report) |
| 5 | shortcuts dialog | yes (3 sections, 10 items) | n/a | n/a | yes (`shortcut dialog` msgctxt) | parity, content **unexercised by the drive gate** |
| 6 | about dialog | yes | n/a | yes | yes | parity |
| 7 | chord diagram | yes (30 fret toggles, 6 top toggles, 1 barre spin, 5 barre images) | yes | yes | n/a | parity |
| 8 | chord diagram toggle (fret cell) | yes | yes | yes | n/a | parity |
| 9 | chord diagram top toggle (string head) | yes | yes | yes | **GAP — accessible label** | **gap** |
| 10 | barre spin | yes | yes | yes | yes | parity, interaction **unexercised by the drive gate** |
| 11 | chord name entry | yes | yes | yes | yes, except 1 site | **gap** (shares #9's cause) |
| 12 | chord preview | yes | yes | yes | n/a | parity |
| 13 | preview buttons | yes | yes | yes (variants click verified; bookmarks click **unexercised**) | n/a | parity |
| 14 | database | yes | n/a | yes | n/a | parity |
| 15 | chord ops | yes | n/a | yes | n/a | parity |
| 16 | chord name algorithm | yes | n/a | yes | n/a | parity |
| 17 | bookmarks / current-chord persistence | yes | n/a | yes | n/a | parity |
| 18 | settings | yes (4 keys, same defaults) | n/a | **substituted mechanism, not located as equivalent** | n/a | **flagged** (see below) |
| 19 | stylesheet | yes | yes (documented class-selector correspondence, verified byte-diff) | n/a | n/a | parity |
| 20 | resources | yes | n/a | n/a | n/a | parity |
| 21 | translations | see `TRANSLATION_PARITY.md` | — | — | 39/47 msgids | **gap**, tracked there |

## The two real gaps

### Gap A — accessible labels never reach the port (components 9, 11)

Upstream sets a translated accessible label on three string-head states and on
the chord-name entry's enharmonic button:

```
src/widgets/chord_diagram_top_toggle.rs:195-204
  TopToggleState::Off   -> gettext!("String {}, Not Open", n)
  TopToggleState::Muted -> gettext!("String {}, Muted", n)
  TopToggleState::Open  -> gettext!("String {}, Open", n)
  .update_property(&[gtk::accessible::Property::Label(&a11y_label)])

src/widgets/chord_name_entry.rs — sets "Enharmonic Equivalent" as both
  tooltip and accessible label on enharmonic_button
```

The port's `chord_diagram_top_toggle.rb:168-169` and
`chord_name_entry.rb:102` (per `TRANSLATION_PARITY.md:112-115`) set the
tooltip only. No call anywhere in `lib/` calls
`Gtk::Accessible#update_property`; `grep -rn update_property lib/` returns
nothing. A screen-reader user gets no string naming which of the six strings a
button is, or that it is open/muted — on every one of the 30+6 controls that
make up the app's main interaction surface. This is located, not asserted: it
is a real, user-facing accessibility regression, not a cosmetic one.

`component-inventory.md` and `TRANSLATION_PARITY.md:112-115` both record this
— but both excuse it by naming the Ruby binding's exception
(`Gtk::Accessible#update_property raises NotImplementedError`) in the same
sentence that states the gap is missing. Per the `accountability-ensurance`
skill, a binding limitation explains why a gap is *hard*, never why it is
*closed* — see `.reports/accountability-ensurance.md`.

### Gap B — GSettings replaced with a JSON file, not located as equivalent (component 18)

`lib/fretboard/settings.rb:10-14` replaces upstream's compiled
`dev.bragefuglseth.Fretboard.gschema.xml` with a JSON file under
`XDG_CONFIG_HOME`. The four keys, defaults and semantics match — but this is
not a cosmetic binding substitution like `Adw.` → `Adwaita::`. It is a
behaviour change with no counterpart named:

- Upstream's settings are visible and editable with `gsettings get/set
  dev.bragefuglseth.Fretboard handedness` and in `dconf-editor`. The port's
  are not — there is no schema registered anywhere the system can see.
- Upstream's schema ships a translatable description for `handedness`
  (`TRANSLATION_PARITY.md` row 10, `Can be either "right-handed" or
  "left-handed".`) which the port cannot carry because there is no schema to
  attach it to. This is the same gap already tracked as a translation gap,
  but it originates here.
- No `data/*.gschema.xml` exists in the port and no `glib-compile-schemas`
  step runs, so the behaviour meson validates upstream (`data/meson.build:52-58`,
  `test('Validate schema file', ...)`) has no port-side analogue at all — see
  the test-parity report.

The code comment framing this ("Requiring an install step to run the app from
a checkout is worse than the alternative, so...") is a reasoned narrative for
an unbuilt feature, which the `accountability-ensurance` skill treats as a
gap wearing a justification regardless of how sound the reasoning sounds.

## Confirmed correspondences (not gaps)

- `AdwAboutDialog` → `Adwaita::AboutDialog`, `Gio::SimpleAction` in place of
  upstream's property action for `win.set-handedness` (`application.rb:67`,
  `window.rb`), constructor-injected callbacks in place of custom GObject
  signals (`user-changed-chord`, `user-changed-value`, `enharmonic-clicked`) —
  all named and located per the house pattern, consistent with the
  `ruby-gtk` skill's guidance and the inventory's "Status refresh" section.
- `style.rb`/`data/style.css` turning upstream's three custom-widget-name CSS
  selectors (`barre-spin`, `chord-diagram-toggle`) into class selectors —
  verified by diff above; the port adds the matching CSS classes in Ruby
  (`add_css_class("barre-spin")` in `barre_spin.rb:70`,
  `add_css_class("chord-diagram-toggle")` presumed in the toggle files).
- `Gtk::Application` + `Adwaita.init` on `startup` in place of
  `Adw::Application`, settled against the `ruby-gtk` skill's
  `Gtk::ApplicationWindow` guidance (inventory blocker 3).

## What this report does not re-prove

Component counts, CSS classes and signal wiring for components 1-3, 6-8,
12-17, 19-20 were verified by `component-inventory.md`'s original per-widget
tables and spot-re-read here (`application.rb`, `primary_menu.rb`,
`barre_spin.rb`, `settings.rb`, a byte diff of the stylesheet). They are not
re-transcribed in full in this document to avoid duplicating that ledger;
this report's job is the four-axis verdict and the two real gaps it finds,
plus flagging which "parity" rows the runtime gate actually exercised — see
`.reports/test-parity.md` for the drive-coverage half of that question.
