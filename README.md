# cosmic-grid — 2D workspace grid for COSMIC

Patches COSMIC 1.0.0 (Pop!_OS 24.04) to arrange workspaces on a bounded 2D grid
(default 5×5) instead of a single vertical/horizontal strip. You start on the
**center cell**, and 4-finger swipes (or Super+Arrows) move one cell in any
direction, wrapping at the edges.

Workspaces are still created on demand and removed when empty — RAM behavior is
identical to stock COSMIC (RAM tracks your apps, not grid cells).

## Enabling the grid

Edit `~/.config/cosmic/com.system76.CosmicComp/v1/workspaces`:

```ron
(
    workspace_mode: OutputBound,
    workspace_layout: Vertical,
    action_on_typing: r#None,
    workspace_wraparound: true,
    workspace_grid: Some((5, 5)),
)
```

- `Some((rows, cols))` enables grid mode. `None` (or omitting the field) = stock
  linear behavior.
- Log out and back in (or reboot) after changing it.
- The Settings app (cosmic-settings) ignores the new field, so nothing else is
  affected.

## Controls

| Action | Input |
|---|---|
| Move to neighbor cell (4 directions) | 4-finger swipe / Super+Arrow* |
| Open workspace overview | Super+W |
| Move window to neighbor cell | drag window into a cell in overview |
| Switch to cell 1–9 | Super+1…9 (top row, left-to-right; cells created on demand) |

\* Stock COSMIC binds Super+Arrows to window-focus navigation. For grid movement,
rebind them to Next/Previous Workspace in Settings → Keyboard → Shortcuts (or add
to `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom` — custom
bindings override defaults). Window focus stays on Super+h/j/k/l. This machine
has the arrow rebind pre-applied.

Swipe feel: your existing up/down convention is preserved exactly (with
`natural_scroll` on, an up swipe reveals the next row below, matching stock).
Left/right is additive.

## Layout & semantics (grid mode)

- Grid positions are fixed per cell; workspace cells cannot be drag-reordered
  (window drag *into* a cell still works).
- Empty cells simply don't exist until you visit them; empty non-active
  workspaces are removed automatically, like stock COSMIC.
- Each monitor gets its own 5×5 grid (`OutputBound` mode, unchanged).

## Build

```bash
./scripts/build.sh       # needs build deps + Rust; see below
```

Build dependencies (Ubuntu 24.04):

```bash
sudo apt install -y cmake pkg-config libegl1-mesa-dev libfontconfig-dev \
  libgbm-dev libinput-dev libpixman-1-dev libseat-dev libsystemd-dev \
  libudev-dev libxcb1-dev libxkbcommon-dev libdisplay-info-dev libfreetype-dev
```

Both repos are pinned: cosmic-comp at the exact installed commit (`bb584aa`),
cosmic-workspaces at 1.0.12. Patches live on the `cosmic-grid` branch of each
checkout.

## Install / Rollback

```bash
sudo ./scripts/install.sh    # backs up stock binaries to stock/, replaces, holds packages
sudo ./scripts/rollback.sh   # restores stock binaries, releases holds
```

Installing replaces only `/usr/bin/cosmic-comp` and `/usr/bin/cosmic-workspaces`
and runs `apt-mark hold` on both. Rollback restores the archived originals.
Log out/in after either.

## Updating COSMIC later

Packages are held, so `apt upgrade` won't touch them. To move to a newer COSMIC
release:

1. `sudo ./scripts/rollback.sh` (stock binaries back, holds released)
2. Upgrade COSMIC normally
3. Re-apply the patch: rebase/apply the `cosmic-grid` branch commits onto the
   new pinned commit(s), rebuild, reinstall. Expect small conflicts as upstream
   evolves.

## Known limitations (v1)

- During a swipe animation the slide axis follows the workspace layout
  (vertical) — horizontal swipes land correctly but animate vertically.
- Super+Shift+Arrows (move window) still use linear next/previous, not the grid.
- Drag-reorder of workspace cells is disabled; toplevels can still be dragged
  into any cell.
- `workspace_mode: Global` isn't grid-aware (stick with `OutputBound`, the
  default).

## Files

- `cosmic-comp/` — compositor source, `cosmic-grid` branch
- `cosmic-workspaces/` — overview app source, `cosmic-grid` branch
- `stock/` — archived original binaries
- `scripts/` — build / install / rollback
- `docs/superpowers/specs/` — design spec
