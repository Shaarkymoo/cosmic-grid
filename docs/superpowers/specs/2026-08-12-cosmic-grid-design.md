# cosmic-grid — 2D workspace grid for COSMIC

**Date**: 2026-08-12
**Status**: Approved for implementation
**System**: Pop!_OS 24.04 (noble), COSMIC 1.0.0, Wayland
**Installed compositor**: cosmic-comp 1.0.0 @ `bb584aab7f8edc428b3328fb4e1be3869ecdc8e8`
**Installed overview**: cosmic-workspaces 1.0.12 (source: pop-os/cosmic-workspaces-epoch)

## Goal

Allow 4-finger touchpad swipes in **all four directions** to move between workspaces
arranged on a **bounded 2D grid** (default 5×5), while keeping every existing behavior
intact:

- Workspaces still created on demand and removed when emptied (RAM identical to today).
- Windows stay on their workspace and persist when you leave.
- Login starts on the **center cell** of the grid.
- Wraparound in both axes.
- Up/down swipe feel must be unchanged; left/right is additive.
- Nothing else on the system may break, and revert must be trivial.

## Why this is a contained change (verified in source)

cosmic-comp already stores workspaces in a flat `Vec<Workspace>` and already exposes
2D workspace **coordinates** to clients end-to-end:

1. `src/shell/mod.rs` → `set_workspace_coordinates(handle, &[idx])` (currently 1D)
2. ext-workspace `Coordinates` event + `cosmic-workspace-unstable-v2` protocol
3. client-toolkit (cctk) → `WorkspaceInfo.coordinates: Vec<u32>` (already parsed)
4. cosmic-workspaces-epoch reads `workspace_layout` from the shared
   `cosmic-comp-config` (git dep) and renders a single-axis flex bar

A grid is therefore a **row-major mapping over the existing flat Vec**
(`idx = row * cols + col`), not a workspace-model rewrite.

## Design

### Config (cosmic-comp-config, inside the cosmic-comp repo)

Add an optional field to `WorkspaceConfig` (crate `cosmic-comp-config`,
`src/workspace.rs`):

```rust
#[serde(default)]
pub workspace_grid: Option<(u32, u32)>,   // Some((rows, cols)) enables grid mode
```

A new *optional field* (not a new `WorkspaceLayout` enum variant) means stock
readers of the RON config (cosmic-settings, applets, launcher) ignore it — no
other package needs rebuilding or pinning.

### Compositor (cosmic-comp)

- **Coordinates** (`src/shell/mod.rs`, `set_workspace_meta`): send `[row, col]`
  instead of `[idx]` when grid mode is active.
- **Gesture deltas** (`src/input/mod.rs`, 4-finger branch): direction → delta
  over the flat Vec, preserving the current natural-scroll convention:
  - Horizontal layout today: Left→+1, Right→−1 (with natural scroll)
  - Vertical layout today: Up→+1, Down→−1 (with natural scroll)
  - Grid: Up/Down = ±`cols`, Left/Right = ±1, same natural-scroll convention,
    so up/down muscle memory is preserved exactly.
- **Wraparound** (`src/input/actions.rs`): in grid mode, wrap per axis
  (row 0 ↔ rows−1; col 0 ↔ cols−1) instead of linear 0 ↔ len−1.
- **Startup**: initial active workspace = center cell `(rows/2, cols/2)`.
- **On-demand bounds**: workspace creation stays on-demand but is capped at
  `rows * cols` per output; auto-removal of empty workspaces unchanged.

### Overview (cosmic-workspaces-epoch)

- `src/view/mod.rs`: add a `Grid` branch to the layout matches — arrange cells
  at their `[row, col]` from `WorkspaceInfo.coordinates` (already received);
  read `workspace_grid` from config (via patched `cosmic-comp-config`).
- Sparse grid: only existing workspaces render; empty cells are absent, same
  create/remove behavior as today.
- `src/widgets/workspace_bar.rs`: keep as the cell widget; grid is arranged at
  the view level.

### Dependency wiring

`cosmic-workspaces-epoch` depends on `cosmic-comp-config` by git rev. Point it at
the patched copy via a `[patch."https://github.com/pop-os/cosmic-comp"]` section
in its `Cargo.toml` (`cosmic-comp-config = { path = "../cosmic-comp/cosmic-comp-config" }`).

## Delivery

- Project root: `/media/shaarky/Data/Projects/cosmic-grid/`
- `cosmic-comp/` — pinned at installed commit `bb584aa`, patch as a branch
- `cosmic-workspaces/` — pinned at 1.0.12, patch as a branch
- `stock/` — archived original binaries for instant revert
- `scripts/` — build, install, rollback
- Packages held: `apt-mark hold cosmic-comp cosmic-workspaces`

### Build dependencies (system)

From cosmic-comp's packaging: libwayland-dev (present), libinput-dev,
libxkbcommon-dev, libseat-dev, libdisplay-info-dev, libpixman-1-dev,
libgbm-dev (mesa), libegl-dev, libudev-dev (systemd), plus pkg-config.
Rust toolchain present (rustc/cargo 1.95).

## Verification checklist (post-install, after session restart)

1. Up/down 4-finger swipe switches workspaces exactly as before.
2. Left/right 4-finger swipe switches workspaces horizontally.
3. Wraparound in both axes.
4. Login lands on the center cell.
5. Apps stay on their workspace; leaving and returning preserves them.
6. Overview renders a grid; cells in correct relative positions.
7. Super+1..9 and Super+Arrows still work.
8. Touchpad pinch zoom and other gestures unaffected.
9. Clean logout/login.

## Rollback

Restore archived binaries from `stock/` (or `apt unhold` + `apt reinstall`),
logout/login. No other system state is modified.
