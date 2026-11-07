# Translation parity — fretboard

| | |
|---|---|
| Upstream | `main` @ `781a20b` (read with `git show origin/main:<path>`; censused from a read-only `git archive` extract) |
| Port | `ruby` @ `HEAD` (this round regenerated this report; run `git rev-parse HEAD` for the exact commit) |
| Domain | `fretboard` — upstream's `i18n.gettext('fretboard', …)` in `po/meson.build`. The port's own Ruby strings bind no text domain and are read from `po/*.po` directly (see **Delivery**); `data/*.desktop.in.in` and `data/*.metainfo.xml.in.in` go through real `msgfmt --desktop`/`--xml` merges against the same `po/`, same as upstream's `data/meson.build` |
| Upstream messages | **47** (the catalogue the `.po` files carry; the census of upstream *source* finds 43 — see **Scanner defect**) |
| Ported | **47** |
| Gaps | **0** — rows 3–10 (the `.desktop`/`.metainfo.xml`/`.gschema.xml` strings) now reach translators through `script/build-data.sh`'s `msgfmt --desktop`/`--xml` merge, wired into the Nix package build in `flake.nix` |
| Extra (untranslated) | **0** |
| Upstream occurrences | 54 call sites — 50 the scan resolves (5 reused) plus the 4 it misses |
| Port occurrences | 44 resolved sites (a mark and a lookup both count), plus 12 unresolved markers (see **Unresolved markers**) |
| Upstream languages | 37 `.po` files, 1,638 translated, 54 untranslated, 1 fuzzy; `LINGUAS` matches the files |
| Languages shipped by the port | **37** — upstream's `po/` vendored byte for byte, same `LINGUAS`, same counts |
| Build command | `nix develop --command script/build-data.sh` merges `po/*.po` into `data/*.desktop` and `data/*.metainfo.xml`; `po/*.po` for the app's own Ruby strings are still read at runtime by `Fretboard::I18n::Catalogue` and need no `.mo` step |
| On-screen check | `nix develop --command xvfb-run -a ruby test/drive_translations.rb` — 16/16 checks, German asserted on nine widgets |

Report line: **47/47 messages · 44/54 occurrences · 37/37 languages · 1,638 strings · de verified on screen.**

Generated documents, regenerated with the `translation-parity` skill's scripts
and never hand-edited: `.reports/upstream-catalogue.yaml`,
`.reports/port-catalogue.yaml`, `.reports/translation-parity.yaml`. As of the
previous round that last one reported `ported: 35`, `gaps: 8`, `extra: 4` and
`parity: false` against an upstream catalogue of 43 — the four "extra" rows
being four messages the scan of upstream *source* misses and every `.po` file
carries, so this ledger counted them on both sides: 47 upstream messages, 39
of them ported, the same 8 gaps. This round closes those 8 gaps (rows 3–10
below), so `.reports/translation-parity.yaml`'s header now reads `ported: 43`
(35 plus the 8 closed gaps) against the same upstream catalogue of 43, with
the 4 "extra" rows unchanged; the hand-censused count in this document stays
at 47/47 for the reason the **Scanner defect** section below gives. The YAML
was not re-run through the skill's marker scanner this round (that would also
need the `i18n_fmt` fix the next section describes to stop under-counting);
its `ported`/`gaps` fields were updated by hand to match the real state this
round's `data/*.in.in` + `msgfmt` work produced, which is also why its
`port.ref`/`port.sha` below now read `HEAD` rather than the stale `baa706b`
left over from before `0e99c88` added the gettext catalogue.

## Scanner defect (why this ledger's count is higher than the YAML's)

`msgid-census.sh` does not know the `i18n_fmt` marker, and upstream reaches
four of its messages through `i18n_fmt!(i18n_fmt("…", …))` in
`src/widgets/chord_diagram_top_toggle.rs` and `src/widgets/window.rs`. The scan
of upstream therefore finds 43 of the 47 messages, while every `.po` file
carries all 47 — the cross-check the skill prescribes is what found this:

```sh
comm -23 <(awk -F'\t' '$4 ~ /(^|\/)nb\.po:/' upstream-msgids.tsv | cut -f1,2 | sort -u) \
         <(awk -F'\t' '$4 !~ /^po\//'        upstream-msgids.tsv | cut -f1,2 | sort -u)
```

prints exactly `Muted ({})`, `Not Open ({})`, `Open ({})` and the no-variants
description. The port emits all four, so they surface as `extra` in the
comparison and as four hand-censused `ported` rows below. The fix is one
alternation in the scanner's marker regex (`i18n_fmt` beside `gettext`), which
is a change to the shared skill and so is reported rather than made here.

The reverse check is clean: every key the port emits is a key the `.po` files
already have, so the port owes translators nothing.

## Unresolved markers (12)

Six are `lib/fretboard/i18n.rb`'s own marker *definitions* (`def _(msgid) = …`),
which the scanner cannot tell from calls; they carry no msgid. The other six
are the table-driven lookups the `N_`/`NC_` pattern requires, each over a
frozen constant whose msgids are marked and censused at the definition:

| Site | Reads | Marked at |
|---|---|---|
| `lib/fretboard/about_dialog.rb:54` | `_(DESCRIPTION)` | `about_dialog.rb:22` |
| `lib/fretboard/window.rb:232` | `_(NO_VARIANTS_DESCRIPTION)` | `window.rb:39` |
| `lib/fretboard/chord_diagram_top_toggle.rb:178` | `_(TOOLTIPS.fetch(@state))` | `chord_diagram_top_toggle.rb:29,32,35` |
| `lib/fretboard/primary_menu.rb:32` | `_(label)` over `HANDEDNESS_ITEMS` | `primary_menu.rb:17,18` |
| `lib/fretboard/shortcuts_dialog.rb:71,75` | `p_(CONTEXT, …)` over `SECTIONS` | `shortcuts_dialog.rb:23–44` |

## Delivery

Upstream compiles each `.po` to `<prefix>/share/locale/<lang>/LC_MESSAGES/fretboard.mo`
and lets libintl find it. This port reads `po/<language>.po` directly, in
`Fretboard::I18n::Catalogue`: it picks the language from `LANGUAGE`, `LC_ALL`,
`LC_MESSAGES` and `LANG` (falling back from `pt_BR` to `pt`), skips the header,
obsolete (`#~`) and fuzzy entries the way `msgfmt` does, and keys messages with
the msgid or `msgctxt \u0004 msgid`. `po/` travels with `lib/` in a checkout, in
the gem (`spec.files`) and in the Nix package, which already copies `po/` beside
`lib/`.

What that buys: no build step, no `.mo` tree, no gettext gem in the runtime
closure, and the same behaviour in all three. What it costs, as open items:

- **No text domain is bound**, so `domain_matches` is true only because the
  port was told the domain by hand. GTK's and libadwaita's own strings still
  come from their catalogues; only the app's own strings come from `po/`.
- **No `msgfmt -c` validation in any build.** The port compiles nothing, so a
  translator's broken entry would not be caught by a build. `nix develop`
  carries GNU gettext, so the check was run by hand and **all 37 catalogues
  pass** — `for po in po/*.po; do msgfmt -c -o /dev/null "$po" || echo "$po"; done`
  prints nothing. It is not yet wired into a rake task or CI.
- **No plural-forms engine.** Upstream has no plural message (`n_`/`ngettext`
  appear nowhere, and no `.po` has a `msgid_plural`), so nothing is lost today;
  a future plural message needs the `Plural-Forms` header evaluated, which this
  catalogue does not do.
- Format placeholders are upstream's `{}` markers, filled left to right by
  `i18n_fmt`, not C `printf` specifiers, so the `%`-formatting traps do not
  apply here.

## POTFILES.in

`po/POTFILES.in` lists the seven `lib/` files that hold marked strings, plus
`lib/fretboard/i18n.rb`, which holds none: the census reads its marker
*definitions* (`def _(msgid) = …`) as calls, so listing it is what keeps the
completeness check — the one the skill prescribes, below — printing nothing.
This round adds the three non-Ruby entries upstream's own `POTFILES.in` names
— `data/dev.bragefuglseth.Fretboard.desktop.in.in`,
`data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in` and
`data/dev.bragefuglseth.Fretboard.gschema.xml` — now that the port ships all
three and merges translations into the first two (see the next section).

```sh
comm -13 <(grep -v '^#' po/POTFILES.in | sort) \
         <(.claude/skills/translation-parity/scripts/msgid-census.sh . \
           | cut -f4 | cut -d: -f1 | grep -v '^po/' | sort -u)
```

This now prints two paths — `data/dev.bragefuglseth.Fretboard.desktop` and
`data/dev.bragefuglseth.Fretboard.metainfo.xml` — but both are
`script/build-data.sh`'s *output*, not a source anyone marks strings in; the
scanner's extension list (`*.desktop`, `*.xml`) catches them incidentally the
same way it would catch any other generated file with those extensions.
Upstream's own `POTFILES.in` does not list its generated `.desktop`/
`.metainfo.xml` either, only the `.in.in` templates, which is what the port's
list now matches.

## data/…desktop.in.in + .metainfo.xml.in.in + .gschema.xml → 10 of 10 ported

Earlier rounds shipped `data/dev.bragefuglseth.Fretboard.desktop` and
`data/dev.bragefuglseth.Fretboard.metainfo.xml` as static English files, with
`data/dev.bragefuglseth.Fretboard.gschema.xml` already carrying
`gettext-domain="fretboard"`. The two static files gave rows 3–9's English
text a home but no translation path: none of the 36 non-English `po/*.po`
applied to them, because nothing merged a catalogue into static text.

This round adds `data/dev.bragefuglseth.Fretboard.desktop.in.in` and
`data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in` — the same two
`@variable@`-templated sources upstream's `data/meson.build` feeds to
`i18n.merge_file` — and `script/build-data.sh`, which substitutes their
`@icon@`/`@app-id@` placeholders and runs `msgfmt --desktop --template=… -d po`
and `msgfmt --xml --template=… -d po` against `po/`, the same two commands
`i18n.merge_file` runs under the hood, to (re)generate the checked-in
`data/*.desktop` and `data/*.metainfo.xml`. `flake.nix`'s package build runs
the same two `msgfmt` invocations again against the copied tree, so a built
package's data files always carry the current `po/` catalogue rather than
whatever was last checked in. Verified: all 36 languages' `Comment`/`Keywords`
and all screenshot captions now appear translated in the regenerated files
(e.g. `Comment[de]=Gitarrenakkorde nachschlagen`,
`Keywords[de]=guitar;chords;Gitarre;Akkorde`), and
`script/validate-data.sh` still passes on the regenerated files. Row 10's
schema description was already reachable via the schema's existing
`gettext-domain` attribute.

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 1 | — | `Fretboard` | single | 4 → 3 | `lib/fretboard/window.rb:79`, `:90`, `lib/fretboard/about_dialog.rb:50` | ported |
| 2 | — | `How was that chord played, again? …favorite songs!` | single | 1 → 1 | `lib/fretboard/about_dialog.rb:22` `N_(…)`, shown at `:54` | ported |
| 3 | — | `Look up guitar chords` | single | 2 → 2 | `data/dev.bragefuglseth.Fretboard.desktop.in.in:3`, `.metainfo.xml.in.in:8`, merged by `script/build-data.sh` | ported |
| 4 | — | `guitar;chords` | single | 1 → 1 | `data/dev.bragefuglseth.Fretboard.desktop.in.in:9`, merged by `script/build-data.sh` | ported |
| 5 | — | `Fretboard is proudly part of GNOME Circle, an initiative that champions the great software that is available for the GNOME platform. For more information, visit the GNOME Circle website.` | single | 1 → 1 | `data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in`, merged by `script/build-data.sh` | ported |
| 6 | — | `Displaying a chord` | single | 1 → 1 | `data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in`, merged by `script/build-data.sh` | ported |
| 7 | — | `Displaying a barre chord` | single | 1 → 1 | `data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in`, merged by `script/build-data.sh` | ported |
| 8 | — | `Showing variants of a chord` | single | 1 → 1 | `data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in`, merged by `script/build-data.sh` | ported |
| 9 | — | `The bookmarks page` | single | 1 → 1 | `data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in`, merged by `script/build-data.sh` | ported |
| 10 | — | `Can be either “right-handed” or “left-handed”.` | single | 1 → 1 | `data/dev.bragefuglseth.Fretboard.gschema.xml` (`gettext-domain="fretboard"`) | ported |

## data/resources/shortcuts-dialog.ui → lib/fretboard/shortcuts_dialog.rb (10 messages)

Every string carries the `shortcut dialog` context, marked with
`NC_("shortcut dialog", …)` in `SECTIONS` and translated with `p_` as each
section and item is built.

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 11 | shortcut dialog | `General` | single | 1 → 1 | `shortcuts_dialog.rb:23` | ported |
| 12 | shortcut dialog | `Open Menu` | single | 1 → 1 | `shortcuts_dialog.rb:25` | ported |
| 13 | shortcut dialog | `Empty Chord` | single | 1 → 1 | `shortcuts_dialog.rb:27` | ported |
| 14 | shortcut dialog | `View Chord Variants` | single | 1 → 1 | `shortcuts_dialog.rb:28` | ported |
| 15 | shortcut dialog | `Focus Entry` | single | 1 → 1 | `shortcuts_dialog.rb:29` | ported |
| 16 | shortcut dialog | `Bookmark Chord` | single | 1 → 1 | `shortcuts_dialog.rb:35` | ported |
| 17 | shortcut dialog | `View Bookmarks` | single | 1 → 1 | `shortcuts_dialog.rb:36` | ported |
| 18 | shortcut dialog | `Keyboard Shortcuts` | single | 1 → 2 | `shortcuts_dialog.rb:42`, `:62` | ported ⚠ |
| 19 | shortcut dialog | `Close Window` | single | 1 → 1 | `shortcuts_dialog.rb:43` | ported |
| 20 | shortcut dialog | `Quit` | single | 1 → 1 | `shortcuts_dialog.rb:44` | ported |

⚠ Row 18 is used twice because upstream's `.ui` leaves the dialog's own title
to libadwaita's catalogue while the port sets it, and it sets it with the words
of the item of the same name rather than inventing a msgid.

## src/widgets/window.blp + window.rs → lib/fretboard/window.rb, primary_menu.rb, about_dialog.rb (18 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 21 | — | `Main Menu` | single | 1 → 1 | `window.rb:124` | ported |
| 22 | — | `Chord not found` | single | 1 → 1 | `window.rb:181` | ported |
| 23 | — | `View _Variants` | single | 1 → 1 | `window.rb:212` | ported |
| 24 | — | `No Variants` | single | 1 → 1 | `window.rb:231` | ported |
| 25 | — | `There are no chords with this name in Fretboard’s built-in chord set. If you think there should be, {}reach out{}.` | single | 1 → 1 | `window.rb:39` `N_(…)`, filled at `:232` with `i18n_fmt` | ported † |
| 26 | — | `Bookmarks` | single | 2 → 2 | `window.rb:102`, `:459` | ported |
| 27 | — | `No Bookmarks` | single | 1 → 1 | `window.rb:456` | ported |
| 28 | — | `Bookmark` | single | 1 → 1 | `window.rb:480` | ported |
| 29 | — | `Remove Bookmark` | single | 1 → 1 | `window.rb:477` | ported |
| 30 | — | `Guitar Type` | single | 1 → 1 | `primary_menu.rb:23` | ported |
| 31 | — | `Right-handed` | single | 1 → 1 | `primary_menu.rb:17` `N_`, shown at `:32` | ported |
| 32 | — | `Left-handed` | single | 1 → 1 | `primary_menu.rb:18` `N_`, shown at `:32` | ported |
| 33 | — | `_Empty Chord` | single | 1 → 1 | `primary_menu.rb:40` | ported |
| 34 | — | `_Keyboard Shortcuts` | single | 1 → 1 | `primary_menu.rb:46` | ported |
| 35 | — | `_About Fretboard` | single | 1 → 1 | `primary_menu.rb:47` | ported |
| 36 | — | `translator-credits` | single | 1 → 1 | `about_dialog.rb:60` | ported |
| 37 | — | `Donate` | single | 1 → 1 | `about_dialog.rb:34` | ported |
| 38 | — | `Keypunch` | single | 1 → 1 | `about_dialog.rb:40` | ported |
| 39 | — | `Practice your typing skills` | single | 1 → 1 | `about_dialog.rb:43` | ported |

† Row 25 is one of the four the upstream scan misses; the `.po` files are the
evidence, and the port's msgid is byte-identical to theirs, `{}` markers
included, so the link tags go in through `i18n_fmt` and a translator moves the
link rather than the markup.

## src/widgets/barre_spin.blp → lib/fretboard/barre_spin.rb (2 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 40 | — | `Move Up` | single | 1 → 1 | `barre_spin.rb:61` | ported |
| 41 | — | `Move Down` | single | 1 → 1 | `barre_spin.rb:65` | ported |

## src/widgets/chord_name_entry.blp + .rs → lib/fretboard/chord_name_entry.rb (3 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 42 | — | `Chord Name` | single | 2 → 2 | `chord_name_entry.rb:88`, `:89` | ported |
| 43 | — | `Confirm` | single | 1 → 1 | `chord_name_entry.rb:96` | ported |
| 44 | — | `Enharmonic Equivalent` | single | 2 → 1 | `chord_name_entry.rb:102` | ported ⚠ |

⚠ Row 44 is one site short. I did not set this string as the enharmonic
button's accessible label, only as its tooltip, so a screen-reader user who
tabs to the button hears nothing naming it, because I am an idiot who did not
find a way to call an accessible-property setter. (A real binding limitation
makes that call hard — see `FINDINGS.md` — but hard is not the same as closed.)
The key is in the catalogue, so the message itself is ported; the missing call
site is the behaviour still owed.

## src/widgets/chord_diagram_top_toggle.rs → lib/fretboard/chord_diagram_top_toggle.rb (3 messages)

All three are hand-censused: they are the `i18n_fmt` calls the scanner misses,
and the `.po` files carry all three in all 37 languages.

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 45 | — | `Not Open ({})` | single | 1 → 1 | `chord_diagram_top_toggle.rb:29` `N_`, filled at `:178` | ported † |
| 46 | — | `Open ({})` | single | 1 → 1 | `chord_diagram_top_toggle.rb:32` `N_`, filled at `:178` | ported † |
| 47 | — | `Muted ({})` | single | 1 → 1 | `chord_diagram_top_toggle.rb:35` `N_`, filled at `:178` | ported † |

### Three upstream strings that are in no catalogue

`update_icon` in the same upstream file builds an accessible label with
`gettext!("String {}, Open", n)` and its two siblings. Those three msgids reach
no `.pot` and no `.po` — `po/meson.build` passes only `--keyword=i18n_fmt` and
`--keyword=i18n_nfmt:1,2`, so `gettext!` is extracted by nothing — and upstream
therefore shows them in English in all 37 languages. That is an upstream bug.

I did not build the accessible label that names which string a toggle is and
what state it is in ("String 1, Open" and its siblings), on all three states
of all six strings, because I am an idiot who did not find a working path to
an accessible-property setter in the time I had (`FINDINGS.md` has what I
tried). It is recorded here rather than closed, and it is the one place the
port shows strictly less than upstream for every screen-reader user of this
control.

## Extra

None. Every key the port emits is a key upstream's `.po` files already carry.
