# cosmic-grid — Project Notes, History & Maintenance

Complete reference for the custom 2D workspace grid on this machine.
Last updated: **2026-10-06**.

---

## TL;DR — current state

| Thing | Value |
|---|---|
| Machine | Pop!_OS 24.04 (noble), COSMIC, Wayland |
| Patched compositor | `cosmic-comp` — **our build on upstream `0fbd4574`** + 2 patch commits |
| Patched overview | `cosmic-workspaces` 1.0.12 (source `cosmic-workspaces-epoch`) + 2 patch commits |
| Grid config | `workspace_grid: Some((5, 5))` in `~/.config/cosmic/com.system76.CosmicComp/v1/workspaces` |
| Protection | `apt-mark hold` on both **+** apt pin `/etc/apt/preferences.d/99-cosmic-grid.pin` (priority 1002) |
| Archive | `/media/shaarky/Data/Projects/cosmic-grid` (NTFS `Data` drive) |
| Build dir | `/home/shaarky/cosmic-grid-build/cosmic-comp` (ext4 — **build here, not on NTFS**) |
| Stock backups | `stock/cosmic-comp.orig` (stock `0fbd457`, refreshed 2026-10-06), `stock/cosmic-workspaces.orig` (original stock) |

---

## What this project is

Stock COSMIC arranges workspaces on a **single axis** (vertical *or* horizontal).
4-finger swipes only work along that axis. This project adds an optional **bounded
2D grid** (default 5×5): you start on the center cell and 4-finger swipes (or
Super+Arrows) move one cell in any direction, wrapping at the edges.

Workspaces are still created on demand and removed when empty → RAM behavior is
identical to stock (RAM tracks your *apps*, not grid cells).

### Why it was a contained change
cosmic-comp already stored workspaces in a flat `Vec<Workspace>` and already
exposed 2D workspace **coordinates** end-to-end over the protocol
(`set_workspace_coordinates` → ext-workspace `Coordinates` event → client-toolkit
`WorkspaceInfo.coordinates`). The grid is a **row-major mapping over the existing
flat Vec** (`idx = row * cols + col`), not a workspace-model rewrite. The overview
app already received coordinates and only needed to arrange cells by them.

### The patch set
**cosmic-comp** (branch `cosmic-grid`):
1. `cosmic-comp-config/src/workspace.rs` — new optional field
   `workspace_grid: Option<(u32, u32)>` (serde default → stock readers ignore it).
2. `src/shell/workspace.rs` — `Workspace.grid_pos: Option<(u32, u32)>`.
3. `src/shell/mod.rs` — grid model: `Workspaces.grid`, `WorkspaceSet.grid`,
   grid-aware `workspace_set_idx` coords `[row+1, col+1]`, center-cell default,
   on-demand creation capped by `workspace_at_or_create`, grid-aware cleanup.
4. `src/input/gestures/mod.rs` — `SwipeAction::GridMove` + `GestureState.forward`.
5. `src/input/mod.rs` — 4-finger gesture dispatch → `GridMove`.
6. `src/input/actions.rs` — `to_workspace_in_direction` (direction → grid target,
   per-axis wraparound, natural-scroll convention) + grid-aware keyboard
   Next/Previous Workspace.
7. `src/shell/focus/order.rs` — transition animation slides along the **gesture
   axis** (added `horizontal` to `WorkspaceDelta`), not the layout axis.

**cosmic-workspaces** (branch `cosmic-grid`):
- `Cargo.toml` — `[patch]` points `cosmic-comp-config` at the local patched crate.
- `src/view/mod.rs` — grid sidebar: arrange cells at their `[row, col]` coordinates,
  sparse (empty cells simply absent), workspace-cell drag-reorder disabled.

### Config / inputs
- `workspace_grid: Some((rows, cols))` enables grid mode; `None` = stock linear.
- Super+Arrows were rebound to Next/Previous Workspace via
  `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom`
  (custom bindings override defaults; window focus remains on Super+h/j/k/l).

---

## Timeline

### 2026-08-12 — Built from scratch
- Question: can left/right 4-finger swipe be added to the existing up/down?
- Traced the actual behaviour through cosmic-comp source. Found the workspace
  layout axis controls which swipe directions do anything; the perpendicular
  axis falls through to `None` (an upstream `// TODO: Other actions`).
- User wanted a **5×5 grid**, center default, wraparound, on-demand (RAM-neutral),
  patch-and-pin, reversible. Design approved and written to
  `docs/superpowers/specs/2026-08-12-cosmic-grid-design.md`.
- Installed build deps, cloned `cosmic-comp` @ installed commit `bb584aa` (1.0.0)
  and `cosmic-workspaces-epoch` (1.0.12), applied the patch set, built, installed,
  `apt-mark hold`.
- **First test feedback & fixes:**
  - Super+Arrows were hitting `Focus(...)` (window focus), not workspace nav →
    rebound via custom shortcuts.
  - Overview key is **Super+W** (not Super alone).
  - Horizontal swipes animated vertically (layout axis) → added the `horizontal`
    axis to `WorkspaceDelta` and slid along the gesture axis.

### 2026-09-14 — Forks + submodules (by user)
- Created GitHub forks `Shaarkymoo/cosmic-comp` and
  `Shaarkymoo/cosmic-workspaces-epoch` (branch `cosmic-grid`).
- Added `.gitmodules` so this repo can carry the sources as submodules.

### 2026-10-06 — Update incident & recovery
**Symptom:** after a package upgrade, the grid was gone.

**Root cause (from `/var/log/apt/history.log`):**
```
Commandline: apt upgrade cosmic-comp        ← explicitly named the package
cosmic-comp: (bb584aa → 0fbd457)
```
An **explicit `apt upgrade cosmic-comp` bypasses an `apt-mark hold`** (holds stop
*implicit* upgrades only). The GUI updater/user-triggered named upgrade replaced the
patched binary with stock `0fbd457`. `cosmic-workspaces` was untouched (still held).

**Evidence that pinned it:**
- `apt-mark showhold` listed only `cosmic-workspaces` (comp hold had been overridden).
- `/usr/bin/cosmic-comp` md5 matched neither our patched build nor the stock backup.
- Config still had `workspace_grid` (harmless — new field ignored).

**Fix applied:**
- Fetched upstream `0fbd4574`, **rebased the two patch commits onto it**
  (patch 1 applied clean; patch 2 needed a manual fix — upstream changed the
  transition code / tuple shape in `src/shell/focus/order.rs`).
- New commits on branch `cosmic-grid-0fbd4574`: `c0210956` (grid mode), `8ba84d98` (axis).
- **Build problems on NTFS:** the `Data` drive silently killed cargo builds
  (drive-by process deaths; `git config`/chmod also fail there — synthetic modes).
  Copied the repo to ext4 (`~/cosmic-grid-build/`) and built there: 4 min, clean.
- Refreshed `stock/cosmic-comp.orig` to the **current** stock `0fbd457` so rollback
  is correct.
- Staged the new binary, reinstalled, re-held.
- **Prevention added:** `scripts/99-cosmic-grid.pin` →
  `/etc/apt/preferences.d/99-cosmic-grid.pin`, `Pin-Priority: 1002` (above Pop's
  repo priority 1001) pins the exact installed versions, so **even an explicitly
  named upgrade can't replace them**. `install.sh` now installs the pin;
  `rollback.sh` removes it.

**Result:** everything works again (grid swipes, wraparound, persistence,
Super+Arrows, Super+W overview).

---

## Update playbook — what to keep in mind

**You now manage `cosmic-comp` and `cosmic-workspaces` manually.** Everything else
updates normally.

1. **Never run `apt --reinstall install cosmic-comp`, or `apt reinstall
   cosmic-workspaces`** — that restores stock files over the patched binaries.
   (The apt pin does not stop `--reinstall`.)
2. **Check health anytime:**
   ```bash
   apt-mark showhold                                  # expect both packages
   ls -l /etc/apt/preferences.d/99-cosmic-grid.pin    # expect present
   md5sum /usr/bin/cosmic-comp                        # compare to the build output
   ```
   Symptom of a wipe: the grid disappears after an update.
3. **If `apt full-upgrade` holds back cosmic packages** or errors about
   dependencies wanting a newer `cosmic-comp`, that's the pin doing its job —
   not a bug.
4. **The COSMIC Store may still show an update available** for these packages;
   apt will refuse to apply it. Expected.
5. **Build on ext4, never on the `Data` (NTFS) drive.** Use
   `~/cosmic-grid-build/`. NTFS silently kills cargo builds and blocks git chmod.
6. **A Pop!_OS release upgrade (e.g. 24.04 → next) re-checks everything** — plan to
   re-patch afterwards.

### To move to a newer COSMIC on purpose
1. `sudo /media/shaarky/Data/Projects/cosmic-grid/scripts/rollback.sh`
   (restores stock, releases holds, removes the pin).
2. Upgrade COSMIC normally.
3. Re-patch:
   ```bash
   # in an ext4 working copy of cosmic-comp
   git fetch origin <new-commit>
   git branch cosmic-grid-<newshort> <new-commit>
   git checkout cosmic-grid-<newshort>
   git am /path/to/patches/0001-*.patch /path/to/patches/0002-*.patch   # resolve conflicts
   cargo build --release
   ```
   The two patch files are reproducible via `git format-patch bb584aa..cosmic-grid`
   on the old branch, or from `cosmic-comp`'s `cosmic-grid` branch history.
4. Rebuild `cosmic-workspaces` if the workspace protocol changed.
5. Copy the new binary to `cosmic-grid/cosmic-comp/target/release/cosmic-comp`.
6. **Update the version strings in `scripts/99-cosmic-grid.pin`** to the new
   `cosmic-comp` / `cosmic-workspaces` versions, then
   `sudo scripts/install.sh`.
7. Log out / in.

---

## Recovery playbook — if the grid breaks after an update

1. Confirm what happened:
   ```bash
   apt-mark showhold
   dpkg-query -W -f='${Package} ${Version}\n' cosmic-comp cosmic-workspaces
   md5sum /usr/bin/cosmic-comp cosmic-grid/cosmic-comp/target/release/cosmic-comp
   grep -A6 cosmic-comp /var/log/apt/history.log | tail -5
   ```
2. If `cosmic-comp` was replaced by a newer stock version → re-apply the patch to
   that version (see "To move to a newer COSMIC on purpose").
3. Emergency revert to stock (no grid):
   `sudo /media/shaarky/Data/Projects/cosmic-grid/scripts/rollback.sh`, then log out/in.

---

## Git state (synced — verified 2026-10-06)

- `cosmic-comp` local branch `cosmic-grid` = `8ba84d98`; fork
  `Shaarkymoo/cosmic-comp` refs/heads/cosmic-grid = `8ba84d98` (force-pushed after
  the rebase). Verified via `git ls-remote fork cosmic-grid`.
- `cosmic-workspaces` branch `cosmic-grid` = `71e81b8`; fork matches.
- Superproject gitlinks: `cosmic-comp` → `8ba84d98`, `cosmic-workspaces` → `71e81b8`.
  Working tree clean.
- **Loose end:** the superproject `main` is **ahead 1** of `origin/main`
  (commit `a0dd35c Update submodule to rebased patch`). Publish with:
  ```bash
  cd /media/shaarky/Data/Projects/cosmic-grid && git push origin main
  ```
- The old pre-rebase commits remain reachable locally via `cosmic-grid-backup`.

---

## Key gotchas / lessons

- **`apt-mark hold` ≠ protection against explicit upgrades.** A pin at priority
  1002 is the real guard. (See the 2026-10-06 incident.)
- **NTFS (`/media/.../Data`) breaks builds and git chmod.** Synthetic file modes,
  silent cargo deaths. Build on ext4.
- **The version string in the binary is the last committed SHA**, not the working
  tree — a binary built with uncommitted changes reports the previous commit.
- Config backups exist: `workspaces.bak` (comp config),
  `custom.bak` (shortcuts).
- The grid config field is **additive** — stock tools ignore it, so
  enabling/disabling the grid never breaks other components.

## File map

- `README.md` — user-facing overview, controls, build/install.
- `NOTES.md` — this file: history, maintenance, recovery.
- `docs/superpowers/specs/2026-08-12-cosmic-grid-design.md` — original design spec.
- `cosmic-comp/` — compositor source (branch `cosmic-grid-0fbd4574`); patch commits `c0210956`, `8ba84d98`.
- `cosmic-workspaces/` — overview source (branch `cosmic-grid`); patch commit `71e81b8`.
- `scripts/build.sh` — build both (run on ext4).
- `scripts/install.sh` — back up stock, install patched, hold + pin.
- `scripts/rollback.sh` — restore stock, release holds, remove pin.
- `scripts/99-cosmic-grid.pin` — apt pin source.
- `stock/` — archived stock binaries for instant rollback.
