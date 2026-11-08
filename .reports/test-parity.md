# Test parity — fretboard

## Census

Ran `.claude/skills/test-parity/scripts/test-census.sh` against a clean
`git archive` of `origin/main` (`781a20b`) and against `ruby` `HEAD`
(`0e99c88`):

```
test-census.sh /tmp/upstream-tree   -> 0 rows
test-census.sh .                    -> 85 rows (test/drive_main_window.rb, test/drive_translations.rb)
```

**Upstream ships zero `#[test]` / `#[cfg(test)] mod tests` functions anywhere
in `src/`, and zero Vala/C/Python/JS/Rust test files.** Confirmed directly,
not just by the script:

```sh
for f in $(git ls-tree -r --name-only origin/main | grep '\.rs$'); do
  git show origin/main:$f | grep -c '#\[test\]\|#\[cfg(test)\]'
done   # every file: 0
```

So the source-level bijection the skill defines is trivially satisfied: 0
upstream tests, 0 required port tests, 0 gap, 0 extra. **This is not the same
as upstream having no test suite** — see below.

## The suite the census script cannot see: upstream's `meson test`

`data/meson.build` registers three `test()` entries, upstream's actual test
suite as `meson test` would run it:

```
data/meson.build:20   test('Validate desktop file', desktop_utils, args: [desktop_file])
data/meson.build:38   test('Validate appstream file', appstreamcli, args: ['validate', ...])
data/meson.build:58   test('Validate schema file', compile_schemas, args: ['--strict', '--dry-run', ...])
```

**Status as of this pass: closed.** `data/dev.bragefuglseth.Fretboard.desktop`,
`.metainfo.xml` and `.gschema.xml` now exist in the port, and
`script/validate-data.sh` (wired as `rake validate_data`) runs the same three
checks upstream's `meson test` runs. Reran it directly in this pass rather than
trusting the prior report:

```
$ nix develop --command bash script/validate-data.sh
== Validate desktop file ==
== Validate appstream file ==
✔ Validation was successful: pedantic: 1
== Validate schema file ==
All three data files are valid.
```

`desktop-file-validate`, `appstreamcli validate --no-net` and
`glib-compile-schemas --strict --dry-run` all pass. Total test-suite
accounting: **upstream 3, port 3, gap 0.** (A prior pass of this report found
this a 3-test gap; `git log` shows it was closed in commit `98a1ac6` after
that finding, which is the accountability loop working as intended — see
`.reports/accountability-ensurance.md` for whether the current wording still
owns what's left.)

## The runtime gate: what 68/68 actually proves

Ran both drivers live, under the fork's own dev shell and Xvfb, rather than
trusting the number handed down:

```
nix develop --command xvfb-run -a ruby test/drive_main_window.rb   -> 52 of 52 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_translations.rb  -> 16 of 16 checks passed, DRIVE OK
```

52 + 16 = 68, matching this round's gate exactly (68 checks, 0 failed). This
is a real, reproduced number, not a stale or fabricated one, and it is a
genuine improvement over the 49/49 a prior pass of this audit measured: the
gap table that prior pass wrote (menu never clicked, barre spin never
clicked, shortcuts item text never asserted, bookmarks-preview button never
clicked, no-variants empty state never rendered, window-close persistence
never round-tripped) is now closed — reading `test/drive_main_window.rb`
line by line confirms:

- **Primary menu**: opens the popover and clicks a `Gio::MenuItem` to flip
  handedness (not just `act(window, "set-handedness", variant)` on the raw
  action) — `[27] opening the primary menu and flipping the guitar over`.
- **Shortcuts dialog**: asserts all 9 items exist and their text matches the
  dialog's own `SECTIONS` data, not just that the dialog object exists —
  `[33]`/`[34]`.
- **Barre spin**: clicks the increment/decrement buttons themselves and
  asserts the 1..12 clamp and sensitivity at both bounds — `[29]`-`[32]`.
- **Bookmarks preview button**: clicked via `signal_emit("clicked")` on the
  bookmarks page's `FlowBoxChild`, not just checked for existence —
  `[146]` region, `drive_main_window.rb:147`.
- **No-variants empty state**: a chord looked up and confirmed to have no
  variants drives `variants_stack` to the empty state for real — `[19]`-`[20]`.
- **Window-close persistence**: the window is actually closed and a size/
  current-chord round-trip through real `Gio::Settings`/`current_chord.json`
  is asserted on reopen — `[37]`-`[38]`.
- **`win.chord-view`** (a no-op upstream and in the port alike, since the
  chord-view page is the permanent navigation-stack root) is now driven and
  asserted as the real no-op it is, matched against upstream's
  `window.rs:push_by_tag("chord-view")` — `[21]`-`[22]`.

### What is still not exercised by any check, this pass

- **Accessible labels** (component 9/11 in `component-parity.md`): still
  n/a — no drive checks accessibility properties, and the underlying
  `update_property` call still does not exist in `lib/` at all. Not a drive
  gap; a code gap (Gap A, still open).
- **`ChordNameAlgorithm.calculate_chord_name`** (`lib/fretboard/
  chord_name_algorithm.rb`, ported from `src/chord_name_algorithm.rs`): the
  fallback algorithm that names a chord from its fingering when the built-in
  database has no matching name. `grep -rn ChordNameAlgorithm test/ spec/`
  returns only the `require_relative` in `window.rb` — **zero call sites in
  either driver script and zero RSpec examples.** Both drives only ever look
  up chords by name through the entry ("C", database hits), so the fallback
  branch at `window.rb:515` (`name || ChordNameAlgorithm.calculate_chord_name
  (chord) || ""`) never runs under test. This is a real, located component
  with zero verification of any kind, not covered by the 68/68 gate despite
  being one of the 21 components `component-inventory.md` lists as "Yes".
- **`spec/` has no examples at all.** `find spec -name '*_spec.rb'` returns
  nothing; the directory holds only `spec_helper.rb` and a `README.md`
  documenting the `kettle-test` harness helpers available to specs that do
  not exist yet. `rake spec` runs RSpec successfully but collects 0 examples
  — confirmed live:
  ```
  $ nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
  No examples found.

  Finished in 0.0002 seconds (files took 0.1 seconds to load)
  0 examples, 0 failures
  ```
  Upstream has no unit tests either (confirmed above), so this is not a
  parity *gap* against upstream's test suite — but it means the port's only
  verification of its pure-logic modules (`chord_ops.rb`, `chord_name_
  algorithm.rb`, `database.rb`) is whatever the two GTK drivers happen to
  exercise end-to-end, which per the point above does not include the
  chord-name-algorithm fallback branch at all. A component with an empty
  RSpec suite and an unexercised code path is unverified, not done.

## The headline finding: the spec suite the dev shell advertises cannot run at all

`flake.nix`'s devShell comment says "The spec runner. The suite is plain
RSpec, so this is enough" and vendors only the bare `pkgs.rubyPackages_3_4.rspec`
package, deliberately keeping `kettle-test`/`kettle-dev` out of the Nix-managed
gemset (comment: "the root Gemfile is kettle-jem's development bundle ...
and must not end up in a packaged app's runtime closure"). But
`spec/spec_helper.rb:23` unconditionally does `require "kettle/test/rspec"`
with no rescue, so the shell's own banner command fails, reproduced live in
this pass:

```
$ nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
LoadError:
  cannot load such file -- kettle/test/rspec
# ./spec/spec_helper.rb:23:in '<top (required)>'
0 examples, 0 failures, 2 errors occurred outside of examples
```

`bundle exec rspec` and `bundle exec rake spec` both fail too —
`bundle list` inside the dev shell shows the installed gemset has no
`rspec-core`, `kettle-test` or `kettle-dev` at all (only the GTK stack, `rake`
and a handful of small gems), and `rake spec`/`rake` run with no such task
defined because `kettle/dev` fails to load (`NOTE: kettle-dev isn't
installed, or is disabled for 3.4.9 in the current environment`).

This matters independently of whether `spec/` has any examples (it has none —
see above): **the command this fork's own documented workflow names as "run
the specs" cannot execute a single example, in the one shell this project
tells you to run it in.** That is not "the suite is thin", it is "the suite
is unreachable" — a stronger and more concrete claim than this report's prior
pass made, and it should be read as the test-parity headline, not a footnote.
It is also not an upstream-parity gap (upstream has no specs to compare
against) — it is a port-tooling defect this audit is obligated to say
plainly rather than let the drive gate's unrelated 68/68 stand in for it.

## Round 4 (this pass) — re-verified live against `HEAD` `407c34b`

Both headline findings from the prior pass were closed in the intervening
commit `1e5a985` ("Make the RSpec suite runnable, cover chord_ops/
chord_name_algorithm/database, and translate data/*.desktop|.metainfo.xml").
Re-ran everything live rather than trusting that commit's message:

```
$ nix develop --command xvfb-run -a ruby test/drive_main_window.rb
56 of 56 checks passed
DRIVE OK

$ nix develop --command xvfb-run -a ruby test/drive_translations.rb
16 of 16 checks passed
DRIVE OK
```

56 + 16 = **72**, matching this round's runtime gate exactly (72 checks,
0 failed). The main-window driver grew from 52 to 56 checks over the prior
pass's 52/16=68 split — the 4 new checks are
`spec/fretboard/{chord_ops,chord_name_algorithm,database}_spec.rb`'s sibling
drive step (`EM11_NOT_IN_DATABASE`, see below) plus its own assertions, not a
renumbering of old ones; read `test/drive_main_window.rb:114-134` to confirm
the new step's checks are additive.

**The RSpec suite now runs, in the exact command the dev shell's own banner
names.** Reproduced live:

```
$ nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
[spec_helper] kettle-test is not available; falling back to plain RSpec (see spec/README.md)

..................................

Finished in 0.0179 seconds (files took 0.37491 seconds to load)
38 examples, 0 failures
```

`spec/spec_helper.rb` now rescues the `kettle/test/rspec` `LoadError` and
falls back to plain RSpec (announced on stderr, not silently), closing last
round's headline finding: the fork's own advertised "run the specs" command
executes and passes. Note `bundle exec rspec` still fails
(`rspec-core is not currently included in the bundle`) — but that is **not**
the command the banner advertises, and the banner's own command is the one
that matters here.

**`ChordNameAlgorithm` is no longer unexercised.** `spec/fretboard/
chord_name_algorithm_spec.rb` exists (part of the 38 examples above), and
`test/drive_main_window.rb:114-134` adds a real end-to-end drive step: clicks
a fingering (`[0,0,0,0,0,2]`, "EM11_NOT_IN_DATABASE") absent from
`data/chords.txt` through the actual diagram-toggle click path, and asserts
`window.rb:515`'s fallback (`name || ChordNameAlgorithm.calculate_chord_name
(chord) || ""`) fires and the entry shows "Em11" — the real code path, not a
direct call to the algorithm bypassing `window.rb`. Confirmed by reading
`test/drive_main_window.rb:117-134`: the step does
`window.call.diagram.chord = EM11_NOT_IN_DATABASE.dup` then
`window.call.diagram.toggle(5, 0).button.signal_emit("clicked")`, and only
then reads `window.call.entry.entry.text`.

## Verdict

- Source-level test bijection: **parity (0/0)**, correctly so — upstream has
  no `#[test]`s.
- Build-validation test bijection (`meson test`): **3 upstream, 3 ported —
  closed.**
- Runtime gate: **72/72 checks pass, reproduced live this round**, exercising
  real interaction paths for every component tracked, including the
  previously-unexercised `ChordNameAlgorithm` fallback, except accessibility
  (see `component-parity.md` Gap A — not a test-parity question, a code gap).
- **The RSpec suite runs and passes (38 examples, 0 failures), in the exact
  command the dev shell's own banner advertises** — closed this round, and
  re-verified live in this pass, not copied from the commit message.
- Remaining open item, same as every prior round: **accessible labels on the
  string-head toggles and the enharmonic button are not built at all**
  (`grep -rn update_property lib/` → nothing). This is a code gap tracked in
  `component-parity.md`, not a missing test — there is nothing to test yet.
