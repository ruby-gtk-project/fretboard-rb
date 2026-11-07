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

`test-census.sh` only scans source-code extensions (`.vala .c .py .js .ts .rs
.rb .cpp`), not `meson.build`, so these three are invisible to the automated
count and were missed by every prior pass at this ledger. They are real
upstream tests — registered with upstream's own test framework, run in CI
(`.github/workflows/*.yml` sets `run-tests: true`) — and they pin exactly the
three files `component-inventory.md` already flags as unported:
the `.desktop.in.in`, the `.metainfo.xml.in.in` and the `.gschema.xml`.

**The port ships none of those three files and runs no equivalent
validation**, so these 3 tests are a genuine, located gap:

| Upstream test | Pins | Port has | State |
|---|---|---|---|
| Validate desktop file | the `.desktop` file is well-formed | no `.desktop` file, no validator | **gap** |
| Validate appstream file | the `.metainfo.xml` is well-formed, resolvable | no `.metainfo.xml` file, no validator | **gap** |
| Validate schema file | the `.gschema.xml` compiles under `--strict` | no `.gschema.xml` (JSON substitute, `settings.rb`) | **gap** |

Total test-suite accounting: **upstream 3, port 0, gap 3, extra 0.**

## The runtime gate: what 49/49 actually proves

Ran both drivers live, under the fork's own dev shell and Xvfb, rather than
trusting the number handed down:

```
nix develop --command xvfb-run -a ruby test/drive_main_window.rb   -> 33 of 33 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_translations.rb  -> 16 of 16 checks passed, DRIVE OK
```

33 + 16 = 49, matching the gate exactly, and `grep -c 'd.check('
test/drive_*.rb` confirms `check` (not `step`) is the suite's real assertion
unit — `gtk_driver.rb:202` prints `"#{checks - failed} of #{checks} checks"`
off `@checks`, which only `check` increments. **The gate's 49/0 is real and
reproduced**, not a stale or fabricated number.

It is also **narrower than "covering 20 components" implies.** Reading both
driver scripts line by line, several inventoried components are touched only
through code that bypasses the actual widget the user would use, or are not
exercised at all:

| Component | What the drive actually does | What it never does |
|---|---|---|
| 4. Primary menu | checks the `MenuButton`'s tooltip text (translation drive only) | never opens the popover; never clicks a menu item; `win.set-handedness` is driven by `act(window, "set-handedness", variant)` directly on the action, never through `handedness_section`'s `Gio::MenuItem`s |
| 5. Shortcuts dialog | checks the dialog object exists and its title | never checks any of the 10 `Adw.ShortcutsItem`s' text or the 3 sections |
| 10. Barre spin | checks `decrement_button.tooltip_text` (translation drive only) | never clicks increment or decrement; never asserts the 1..12 clamp or the sensitivity-at-the-bounds behaviour described in `component-inventory.md` component 10 |
| 13. Preview buttons (bookmarks variant) | checks a bookmarks-page `FlowBoxChild` exists | never clicks it — only the *variants*-page button is click-tested (`drive_main_window.rb:131`) |
| 7. Chord diagram's `no_variants_page` empty state | checked for its *text* (translation drive, with a chord that happens to have variants anyway — the check runs against "C", which has variants) | the empty state is never actually driven to render: no drive ever looks up a chord with zero variants, so `Adw.StatusPage no_variants_page`'s real appearance path (`variants_stack` flipping to `no-variants`) never runs |
| 3. Window | `close-request` save-on-close (window size, maximized state, current chord to `current_chord.json`) | never exercised — the drive never closes the window and reopens a second instance to confirm persistence round-trips |
| 9. Accessible labels | n/a | confirmed absent entirely — see `.reports/component-parity.md` Gap A; no drive checks accessibility properties at all |

None of this makes the 49 checks false. It means **"49 checks, 0 failed,
covering 20 components" overstates what was verified**: several of those 20
components are "covered" only in the sense that a file with that name exists
and one static property of it was read, not that its behaviour was driven.
Per this audit's brief, a component a check does not exercise through its
real interaction path is unverified, not done — the menu's five items, the
spinner's two buttons, one of the two preview-button call sites, the
no-variants empty state's actual render path, and window-close persistence
are all in that state right now.

## Verdict

- Source-level test bijection: **parity (0/0)**, correctly so.
- Build-validation test bijection (`meson test`): **3 upstream, 0 ported — gap.**
- Runtime gate: **49/49 checks pass, reproduced live** — but exercises roughly
  14-15 of the 20 non-translation components through a real interaction path;
  the rest are touched by a property read only, and the window-close
  persistence path and the no-variants empty-state render path are not
  touched at all.
