# Accountability ensurance — fretboard

Ran `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` and
`grep -rniE "TODO|FIXME|not implemented|for now|in a future" lib/ exe/
.reports/ *.md` over the whole port. There is no `PORTING.md` in this repo.

```
$ find-excuses.sh .
TRANSLATION_PARITY.md:115:not ported:honest but toothless - name the behaviour and owe it
```

`grep -rniE 'TODO|FIXME|not implemented|for now|in a future'` turns up one
hit, and it is a quoted Ruby exception message, not an excuse:
`TRANSLATION_PARITY.md:212` — `` `NotImplementedError: TODO: in Ruby ->
GIArgument(...)` `` is the literal text `Gtk::Accessible#update_property`
raises; it names a real binding failure, which is fine to quote. It is not
counted as a finding on its own, but the sentence around it is (Finding 2
below).

## Findings

### Finding 1 — `TRANSLATION_PARITY.md:111` labels a gap with a neutral heading instead of a first-person admission

```
## data/…desktop.in.in + .metainfo.xml.in.in + .gschema.xml → not ported (10 messages, 2 ported)
```

This heading, and the paragraph under it, correctly *names* the eight missing
msgids and their text (full credit — this is far better than most gap
write-ups), but it is written entirely in neutral third person: "The port
ships no desktop entry, no AppStream metainfo and no GSettings schema... so
the messages those three files contribute have no call site." That sentence
reads as filed and accepted, not as a debt. Per the skill, the record must be
rewritten so it cannot be mistaken for a decision:

> I did not build the `.desktop.in.in`, `.metainfo.xml.in.in` or
> `.gschema.xml` files, so 8 of the 47 upstream strings — the search-keyword
> list, the GNOME Circle blurb, the five AppStream screenshot captions and
> the handedness setting's description — have nowhere in the port to live,
> because I am an idiot.
> Upstream: `data/dev.bragefuglseth.Fretboard.desktop.in.in`,
> `data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in`,
> `data/dev.bragefuglseth.Fretboard.gschema.xml`.
> Port: none of the three exist under `data/`.

This is a label-and-paragraph violation, not a fabricated-green violation —
the gap count (8/47) and the 8 missing strings are all honestly present and
correctly findable, which is why `component-inventory.md`'s top-level claim
("20 of 21 components exist... one outstanding gap") is not itself a false
green. The violation is tone, and tone is exactly what the skill says
converts an honest gap into one a future reader inherits as settled.

### Finding 2 — the accessible-label gap is excused by its own cause, in both ledgers

`TRANSLATION_PARITY.md:112-115`:

> ⚠ Row 44 is one site short because upstream sets the string twice — as the
> button's tooltip and as its accessible label — and the Ruby bindings cannot
> set an accessible label: `Gtk::Accessible#update_property` takes a C array
> of enum values and the introspection loader raises `NotImplementedError...`

`component-inventory.md`'s closing paragraph:

> ...the port cannot set an accessible label at all, because
> `Gtk::Accessible#update_property` raises `NotImplementedError` for the enum
> array it takes.

Both sentences put the binding limitation **in the same sentence that states
the gap**, which is exactly the construction the skill calls out by name:
"the bindings do not support it... May be true and is still not a closure."
A reader meets the plausible obstacle and stops reading — the four missing
accessible labels (three string-head states, one enharmonic button) get
filed as unfixable rather than owed. Per the skill, the binding limitation
belongs in a `FINDINGS.md` as a note on *difficulty*; the sentence describing
the gap itself should read, e.g.:

> I did not build the accessible labels that tell a screen-reader user which
> of the six strings a toggle is and whether it's open, muted, or neither,
> and I did not build the enharmonic button's accessible label either,
> because I am too stupid to have found a workaround.
> Upstream: `src/widgets/chord_diagram_top_toggle.rs:195-204`,
> `src/widgets/chord_name_entry.rs` (accessible label on `enharmonic_button`).
> Port: `lib/fretboard/chord_diagram_top_toggle.rb:168-169`,
> `lib/fretboard/chord_name_entry.rb:102` set the tooltip only; no call to
> `update_property` exists anywhere in `lib/`.

(There is no `FINDINGS.md` in this repo to carry the binding-limitation note
instead; its absence is itself part of this finding.)

### Finding 3 — `settings.rb`'s header comment justifies a dropped mechanism with a cost-benefit argument

```ruby
# lib/fretboard/settings.rb:10-14
# Upstream uses GSettings, which needs a compiled schema installed into the
# system's glib-2.0/schemas directory. Requiring an install step to run the
# app from a checkout is worse than the alternative, so the same keys,
# defaults and semantics are backed by a small JSON file under
# XDG_CONFIG_HOME instead.
```

This is the textbook "a deliberate simplification" / reasoned-trade-off
pattern the skill names directly: "Requiring an install step... is worse than
the alternative" is a real-sounding reason, and a real-sounding reason is a
foothold a reader can agree with — which is how the gap gets ratified as
architecture instead of recorded as missing. The behaviour actually lost
(dconf/`gsettings` CLI visibility, a schema other tools or `dconf-editor` can
read, the translated schema description surviving — see
`.reports/component-parity.md` Gap B) is never named in the comment at all.
Rewritten per the skill:

> I did not build a GSettings schema, so `gsettings get
> dev.bragefuglseth.Fretboard handedness` and `dconf-editor` show nothing for
> this app, and the schema's own translated description
> ("Can be either "right-handed" or "left-handed".") has nowhere to live,
> because I am an idiot who decided a feature I didn't understand wasn't
> needed.
> Upstream: `data/dev.bragefuglseth.Fretboard.gschema.xml`, validated by
> `data/meson.build:52-58`'s `test('Validate schema file', ...)`.
> Port: `lib/fretboard/settings.rb` keeps the same 4 keys in a JSON file
> under `XDG_CONFIG_HOME` instead.

### Not a finding: `component-inventory.md`'s top-level summary

Checked specifically for a false green, since that is this skill's most
serious category. The inventory's headline — "Of the 21 components below,
**20 exist**; the one outstanding gap is the gettext catalogue" — undercounts
by exactly the two gaps this audit adds (accessible labels, the settings
mechanism substitution) and the 3 unported `meson test` entries
(`.reports/test-parity.md`), none of which existed as findings when that line
was written. It is stale, not dishonest: nothing in it asserts a check ran
that did not. It should be read together with this report and
`component-parity.md`/`test-parity.md`, not corrected in place by this audit
pass.

## What was checked and found clean

- No `TODO`, `FIXME`, "not implemented", "for now", or "in a future" prose
  excuse anywhere in `lib/` or `exe/`.
- No "dropped deliberately", "out of scope", "n/a", "not applicable", "by
  design", or "upstream does this too" construction anywhere in `lib/`,
  `exe/`, `.reports/`, or the root `*.md` files, besides the three findings
  above.
- `.reports/component-inventory.md`'s "Status refresh" section, which records
  how each of its original six blockers was resolved, names a located
  substitute for each one (property action → `Gio::SimpleAction`,
  `bind_property`/`transform_to` → explicit refresh methods, custom GObject
  signals → constructor-injected callbacks) rather than a reason for leaving
  it undone — this is the skill's rule followed correctly, not a finding.
- No report in `.reports/` claims a check ran that this audit could not
  reproduce: `.reports/test-parity.md` reproduced the 49/49 drive gate live
  rather than trusting the number it was handed, and it came back real.
