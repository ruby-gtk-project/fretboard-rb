# Accountability ensurance — fretboard

Re-run this pass against `HEAD` `dcfe7a6` (2026-11-07), after the prior pass's
three findings prompted real fixes in `98a1ac6`. Ran
`.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` and
`grep -rniE "TODO|FIXME|not implemented|for now|in a future" lib/ exe/
.reports/ *.md` over the whole port, including this round's own edits to
`.reports/`. There is no `PORTING.md` in this repo.

```
$ find-excuses.sh .
FINDINGS.md:20:TODO::a status field - reads as filed, and filed reads as approved
.reports/component-parity.md:21,22,24-28,32-40:n/a:...
.reports/test-parity.md:105:n/a:...
.reports/accountability-ensurance.md:...:(this file quoting its own prior findings)
```

```
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future' lib/ exe/ .reports/ *.md
FINDINGS.md:20: ... NotImplementedError ...
(plus this report's own prior-findings quotes)
```

Both hits are the same non-finding the prior pass already cleared:
`FINDINGS.md:20` quotes the literal Ruby exception text
`` `NotImplementedError: TODO: in Ruby -> GIArgument(...)` `` that
`Gtk::Accessible#update_property` actually raises — a real binding failure,
fine to quote verbatim. The `n/a` hits in `component-parity.md`/
`test-parity.md` are table cells meaning "this axis does not apply to this
component" (e.g. a non-visual component has no CSS "Style" column), not the
skill's "asserts the behaviour cannot exist here" pattern — checked each one
by hand against its row; none excuses a real gap.

## The three prior findings: resolved, verified by re-reading the current text

A prior pass of this report (before `98a1ac6`) found three violations. All
three texts have since been rewritten and the rewrites hold up on re-read:

- **Finding 1** (neutral-tone heading in `TRANSLATION_PARITY.md`): the
  heading is now `## data/…desktop.in.in + .metainfo.xml.in.in +
  .gschema.xml → 2 of 10 ported`, and the paragraph under it opens "I did not
  ship a desktop entry, an AppStream metainfo file or a GSettings schema,
  because I am an idiot who decided three files upstream ships weren't
  needed." First-person, admission first, no neutral label. Fixed.
- **Finding 2** (binding limitation excusing the accessible-label gap in the
  same sentence that states it): `TRANSLATION_PARITY.md` row 44 now reads "I
  did not set this string as the enharmonic button's accessible label... [here is what I tried, in FINDINGS.md] but hard is not the same as closed" — the admission leads, the difficulty note is now in
  `FINDINGS.md` (which now exists) and is explicitly flagged as not a
  closure. `component-inventory.md`'s accessible-label sentence is gone from
  that file's closing paragraph entirely; the gap now lives only in
  `component-parity.md` Gap A and `TRANSLATION_PARITY.md`, both first-person.
  Fixed.
- **Finding 3** (`settings.rb`'s cost-benefit comment for dropping
  GSettings): the mechanism was not just re-described, it was rebuilt —
  `settings.rb` is a real `Gio::Settings` wrapper now, the schema file
  exists and validates, and the comment says so ("carried over byte for
  byte rather than reimplemented as a side file"). This is the strongest
  possible resolution: the gap was closed, not merely reworded. Fixed.

## New finding — the dev shell's own banner names a command that cannot run

Reproduced live in this pass, independent of any report's wording:

```
$ nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
LoadError:
  cannot load such file -- kettle/test/rspec
```

`flake.nix`'s devShell prints this exact command as `"run the specs:"` on
every `nix develop`, and it fails before collecting a single example.
`bundle list` inside the shell confirms `kettle-test`/`rspec-core` are not
in the installed gemset at all. This is not a tone problem or an excused
gap — it is a claim of capability ("run the specs") that is false as
written, in the one place (the dev shell's own banner) a developer would
trust it. Per the skill's most serious category — a false green — this is
close to one: nothing in `.reports/` or `TRANSLATION_PARITY.md` asserts the
spec suite runs, so no *report* is lying, but the *project's own tooling*
asserts a false capability to anyone who runs `nix develop` and reads its
output. Recorded here because an accountability audit that only checks
`lib/`, `exe/` and `.reports/` prose would miss it; see
`.reports/test-parity.md` for the full reproduction. No one has said this is
fine or acceptable anywhere in the repo — it simply has not been noticed
until this pass, which is itself worth saying plainly rather than folding
into a "status refresh" note.

## Minor hygiene (not a parity finding)

`TRANSLATION_PARITY.md`'s header table and its generated sibling
`.reports/translation-parity.yaml` both say `ruby @ baa706b` — a commit from
2026-11-02T21:53, which is *before* `0e99c88` ("Port the gettext catalogue
and wire the markers through lib/", 2026-11-03T00:11) even existed. The
message counts both documents report are real (confirmed above and by an
independent re-run of the census script in this pass, which found zero
upstream keys missing from the port's source), so the ref string is simply
wrong bookkeeping — probably copied forward from an earlier pass — not a
sign the census itself ran against the wrong tree. Flagged so it doesn't
compound, not rewritten here since this audit's brief is finding gaps, not
copy-editing every report it touches.

## What was checked and found clean, this pass

- No `TODO`, `FIXME`, "not implemented", "for now", or "in a future" prose
  excuse anywhere in `lib/` or `exe/`.
- No "dropped deliberately", "out of scope", "not applicable", "by design",
  or "upstream does this too" construction anywhere in `lib/`, `exe/`, the
  root `*.md` files, or `.reports/`.
- Every gap this round's `component-parity.md` and `test-parity.md` reports
  (accessible labels; the three untranslated data files; `ChordNameAlgorithm`
  being unexercised; the spec suite being unable to load) is stated as a
  first-person admission or a located, reproduced fact — none is wrapped in
  a reason that reads as a decision.
- `component-inventory.md`'s "Re-verified 2026-11-07" footer (added this
  pass) and `component-parity.md`'s "Status refresh (round 3)" section both
  name what changed and what didn't, rather than silently updating a verdict
  in place — the skill's rule for correcting a stale claim, followed.
- Every number this report or its siblings cites for the drive gate (68
  checks, 0 failed) and the data-validation gate (3/3) was reproduced live
  in this pass, not copied from a prior report's text.
