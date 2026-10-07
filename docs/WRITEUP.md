# cosmic-grid — Writeup Source Material

Purpose, decisions, problems and solutions behind the 2D COSMIC workspace grid.
Written for later reuse in a blog post / writeup. Companion docs:
[`README.md`](../README.md) (usage), [`NOTES.md`](../NOTES.md) (ops/maintenance).

---

## 1. Purpose

Give COSMIC (Pop!_OS 24.04) a **2D workspace grid** navigable with 4-finger
touchpad swipes in all four directions, while behaving exactly like stock COSMIC
in every other respect — same RAM behavior, same app-persistence, same
keyboard/protocol semantics, fully reversible.

The request started as a question: *"my current desktop switches screens by
swiping up or down with 4 fingers — is there a left/right possibility too?"* It
became a wish for a **5×5 workspace grid**, then a full compositor patch.

## 2. Requirements (as the user stated them)

- 4-finger swipes should work **left/right as well as up/down**.
- A **5×5 grid**, starting on the **center** cell (later: "the centre is
  determined by what program I open on a screen" — i.e. it just needs a stable
  home cell).
- Wraparound at the edges.
- **RAM behavior must match stock** — "if it does or does not [use more RAM], I
  want the new config to reflect that."
- Same abilities as before: start an app on one screen, leave it, open another,
  come back to the first.
- **Must not break anything else**, must not "interfere or cause problems later
  that will be very hard to solve."
- Reversible; rebooting to apply is fine.
- Static grid was optional: "if having a static grid causes issues we can leave
  it out."

## 3. Background — how COSMIC worked

Investigation of the installed stack revealed:

- **Workspaces are a flat `Vec<Workspace>`** per output, activated by a flat
  `usize` index. Navigation is `to_next_workspace` / `to_previous_workspace`
  (±1 with linear wraparound).
- **4-finger gestures are hardcoded to the workspace-layout axis.** A gesture
  direction is mapped to "next/previous" only if it matches the layout
  (`Vertical` → up/down; `Horizontal` → left/right). The perpendicular axis falls
  through to `None` with an upstream `// TODO: Other actions`.
- **2D coordinates already existed end-to-end**: `set_workspace_coordinates(handle,
  &[idx])` → ext-workspace `Coordinates` event → client-toolkit
  `WorkspaceInfo.coordinates: Vec<u32>` → the overview app. The compositor was
  sending a **1D** coordinate (`[idx]`) and nobody used it for layout.
- `WorkspaceLayout` is a **single-axis** enum (`Vertical | Horizontal`) — no grid.

**Key insight:** a grid is a **row-major mapping over the existing flat Vec**
(`idx = row*cols + col`, up/down = ±cols, left/right = ±1). Not a model rewrite.

## 4. Key decisions

| # | Decision | Alternatives considered | Why |
|---|---|---|---|
| D1 | **Do it as a compositor patch**, not a config tweak | The gesture→axis mapping is hardcoded; no extension system in COSMIC 1.0; third-party gesture tools (touchegg/fusuma) don't work on Wayland without compositor support | It's the only real route |
| D2 | **2D grid via row-major mapping over the flat Vec** | Refactor to a true 2D workspace model | The flat Vec already *is* the grid; a refactor would touch IPC/shortcuts/move-window for no user gain |
| D3 | **On-demand workspaces, grid as a boundary only** | Pre-allocate all 25 cells | Preserves stock RAM behavior and create/remove semantics exactly ("same as now"). 5×5 is a bound, not 25 live workspaces |
| D4 | **New optional config field `workspace_grid: Option<(u32,u32)>`** | New `WorkspaceLayout::Grid` enum variant | A new *field* is additive: stock readers (cosmic-settings, applets, launcher) ignore it via serde default. A new enum *variant* breaks deserialization in every package that reads the config → would force rebuilding/pinning ~5 packages instead of 2 |
| D5 | **Reuse the existing coordinates protocol** | Add a new protocol / encode position in names | The whole pipeline already existed; only the payload changed from `[idx]` to `[row+1, col+1]` |
| D6 | **Wraparound on both axes** | Stop at edges | Matches the user's existing `workspace_wraparound: true` |
| D7 | **Default = center cell = `(rows/2, cols/2)`** | Top-left default | User's request; a natural "home" |
| D8 | **Preserve the natural-scroll convention exactly** for up/down; left/right additive | Re-map directions | Keeps muscle memory — up/down must feel identical to before |
| D9 | **Patch + pin (apt hold)** | Rebuild on every update; trial-only | User chose durability; documents a repeatable re-patch procedure |
| D10 | **Grid positions are fixed; no workspace-cell drag-reorder** | Allow reordering cells | Reordering is meaningless on a fixed grid; window-drag *into* a cell still works |
| D11 | **Transition animation slides along the gesture axis** (added `horizontal` to `WorkspaceDelta`) | Leave it following the layout axis | Upstream slides vertically for a vertical layout regardless of swipe; horizontal swipes looked wrong |
| D12 | **Keyboard: literal directions, rebound via custom shortcuts** | Patch default keybindings | Stock binds Super+Arrows to window focus; custom shortcuts override by key without touching system files |
| D13 | **Build from the exact installed release commit** (later rebased to the new one) | Build from master | Drop-in binary, no config/IPC drift |

## 5. Problems encountered & how they were solved

### P1 — Super+Arrows moved window focus, not workspaces
- **Symptom:** after the grid was installed, `Super+Arrow` changed which window
  was focused and never moved cells.
- **Investigation:** `/usr/share/cosmic/.../Shortcuts/v1/defaults` binds
  `Super+Arrow` → `Focus(Left/Right/Up/Down)`. Workspace switching defaults to
  `Super+Ctrl+Arrows`.
- **Root cause:** the arrow keys were never bound to workspace actions.
- **Fix:** added custom bindings in
  `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom` mapping
  `Super+←/→/↑/↓` → `PreviousWorkspace`/`NextWorkspace`. Custom bindings override
  defaults by exact key (a `HashMap.extend`), and cosmic-comp hot-reloads them.
  Window focus remains on `Super+h/j/k/l`. In grid mode the action *name* is
  irrelevant — only the key's inferred direction matters.
- **Lesson:** read the actual default keybinding table before assuming a shortcut.

### P2 — The workspace overview didn't open with Super
- **Symptom:** pressing Super did nothing that looked like an overview.
- **Cause:** Super alone opens the launcher; the overview is `Super+W`
  (`System(WorkspaceOverview)`).
- **Fix:** documented `Super+W`. No code change.

### P3 — Horizontal swipes animated vertically
- **Symptom:** left/right swipes switched to the correct cell but the transition
  slid up/down.
- **Investigation:** the renderer (`src/shell/focus/order.rs`) selected the slide
  axis from `shell.workspaces.layout` (still `Vertical`), not from the gesture.
- **Root cause:** `WorkspaceDelta` carried no axis information.
- **Fix:** added a `horizontal: bool` to `WorkspaceDelta::{Gesture,GestureEnd}` and
  threaded it from gesture start (direction → axis) → swipe progress → settle
  spring → renderer offset. Linear/keyboard paths derive axis from layout as
  before (no behavior change off the grid).
- **Lesson:** a visual bug can be logically separate from the state machine —
  trace where the *rendering* decision is made.

### P4 — The upgrade wiped the patch ("apt hold didn't work")
- **Symptom:** after "a lot of packages" updated, the grid was gone.
- **Investigation:** `apt-mark showhold` listed only `cosmic-workspaces`;
  `/usr/bin/cosmic-comp` md5 matched neither the patch nor the stock backup;
  `dpkg -l` showed a newer stock `cosmic-comp`. `/var/log/apt/history.log`:
  `Commandline: apt upgrade cosmic-comp` (package explicitly named).
- **Root cause:** **an explicitly-named `apt upgrade <pkg>` bypasses an
  `apt-mark hold`.** Holds only stop *implicit* upgrades. The GUI updater /
  named upgrade forced the new stock binary in.
- **Fix:**
  1. Fetched upstream `0fbd4574` and **rebased the two patch commits onto it**
     (patch 1 clean; patch 2 conflicted in `order.rs` — resolved manually).
  2. Built on **ext4** (see P6), installed the new binary, refreshed the stock
     backup to the current stock `0fbd457` (so rollback is correct).
  3. **Added an apt pin** `/etc/apt/preferences.d/99-cosmic-grid.pin` with
     `Pin-Priority: 1002` (above Pop's repo priority 1001) pinning the exact
     versions — now even an explicitly-named upgrade can't replace them.
     `install.sh` installs the pin; `rollback.sh` removes it.
- **Lesson:** `apt-mark hold` is not protection against a user/GUI naming the
  package. Pin at a priority above the repo for real protection.

### P5 — `git config`/`chmod` failed on the project drive
- **Symptom:** `git status` showed all files modified; `git config` failed with
  "chmod on .git/config.lock failed: Operation not permitted".
- **Investigation:** the project lives on an NTFS partition
  (`/dev/nvme0n1p7 … fuseblk … user_id=0`). NTFS has no Unix mode bits — they're
  synthetic (everything looks 755), and chmod by a non-owner fails.
- **Fix:** use `git -c core.fileMode=false …` for operations (and
  `safe.directory`), or work on ext4. Documented: **build on ext4**.
- **Lesson:** git + NTFS is fragile; keep build trees on a native filesystem.

### P6 — Cargo builds silently died on NTFS
- **Symptom:** the patched compositor build stopped mid-way with no error; no
  cargo/rustc processes left; low load, plenty of RAM.
- **Investigation:** repeated silent deaths building on the NTFS `Data` drive
  (also a hang once: rustc blocked on a futex with ~3 s CPU in 6 min).
- **Root cause:** unreliable behaviour building on the NTFS/fuseblk mount.
- **Fix:** copied the repo (excluding `target/`) to `/home/shaarky/cosmic-grid-build/`
  on ext4 and built there — **4 minutes, clean**, first try.
- **Lesson:** when builds die mysteriously, suspect the filesystem before the code.

### P7 — Rebase conflict on the animation code
- **Symptom:** `git am` of the axis-fix patch failed at
  `src/shell/focus/order.rs:160`.
- **Investigation:** upstream `0fbd4574` changed that function's tuple shape
  (`Some((previous, previous_idx, has_fullscreen, offset))`) and surrounding code.
- **Fix:** applied the axis change manually (added the `horizontal` destructuring
  and switched the offset matches from `(layout, forward)` to `(horizontal,
  forward)`), kept upstream's new tuple shape. `git apply` being atomic meant the
  other files' hunks hadn't applied, so those were re-applied manually too.
- **Lesson:** when rebasing a patch that touches rapidly-moving rendering code,
  expect small structural conflicts; apply with `-c core.fileMode=false` on NTFS.

### P8 — Minor compile iterations during development
- Borrow-checker conflicts in the gesture dispatch (calling `self` while a
  `gesture_state` borrow was live) → resolved by capturing a "pending action" and
  dispatching after the borrow ends.
- A moved local (`activate_action`) causing an unused-assignment warning → scoped
  the declaration.
- `widget::space::fixed` doesn't exist in this libcosmic version, and `vec![]`
  needs `Clone` → used `Space::new().width().height()` and `resize_with`.
- **Lesson:** work in small compile-fix cycles; the Rust type system catches the
  threading of new parameters across the codebase immediately.

## 6. Outcome

- 4-finger swipes work in all four directions on a 5×5 grid; wraparound both
  axes; boot to the center cell; apps persist per workspace; on-demand creation
  keeps RAM identical to stock.
- Super+Arrows move cells; Super+W opens the grid overview; window focus on
  `Super+h/j/k/l`.
- Only `cosmic-comp` + `cosmic-workspaces` are replaced, pinned to exact versions
  by hold **and** apt pin; stock binaries archived for instant rollback.

## 7. Lessons / takeaways

- **Read the source.** The turning point was discovering COSMIC already had 2D
  workspace coordinates — turning a "rewrite" into a small, contained patch.
- **Backward-compatible config changes (new optional field) beat breaking ones
  (new enum variant).** It shrank the blast radius from ~5 packages to 2.
- **`apt-mark hold` ≠ upgrade-proof.** Use an apt pin above the repo priority.
- **Filesystem matters.** NTFS silently sabotaged builds; ext4 was 4× faster and
  reliable.
- **Verify the actual default keybindings** and the actual overview hotkey rather
  than assuming.
- **Keep the re-patch path reproducible**: pinned commits + patch files + a
  documented procedure + archived stock binaries = safe to iterate.

## 8. Technical appendix

**Patch files:** reproducible with `git format-patch bb584aa..cosmic-grid`
cosmic-comp's branch history.

**cosmic-comp patch commits (on upstream `0fbd4574`):**
- `c0210956` — "Add optional 2D workspace grid mode (workspace_grid config)"
- `8ba84d98` — "Animate workspace swipes along the gesture axis (grid mode)
  instead of the layout axis"

**cosmic-workspaces patch commit:** `71e81b8` — "Render workspace sidebar as a 2D
grid when workspace_grid is set" (+ build fix).

**Files touched (cosmic-comp):** `cosmic-comp-config/src/workspace.rs`,
`src/shell/workspace.rs`, `src/shell/mod.rs`, `src/input/gestures/mod.rs`,
`src/input/mod.rs`, `src/input/actions.rs`, `src/shell/focus/order.rs`.

**Config:** `~/.config/cosmic/com.system76.CosmicComp/v1/workspaces` →
`workspace_grid: Some((5, 5))`.

**Key protection file:** `/etc/apt/preferences.d/99-cosmic-grid.pin`.

**Build deps (Ubuntu 24.04):** `cmake pkg-config libegl1-mesa-dev
libfontconfig-dev libgbm-dev libinput-dev libpixman-1-dev libseat-dev
libsystemd-dev libudev-dev libxcb1-dev libxkbcommon-dev libdisplay-info-dev
libfreetype-dev`.
