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

## Get the source

```bash
git clone --recurse-submodules https://github.com/Shaarkymoo/cosmic-grid.git
```

The patched compositor and overview live on the `cosmic-grid` branch of these
forks:

- [Shaarkymoo/cosmic-comp](https://github.com/Shaarkymoo/cosmic-comp) — rebased
  onto upstream `0fbd4574` + 2 patch commits
- [Shaarkymoo/cosmic-workspaces-epoch](https://github.com/Shaarkymoo/cosmic-workspaces-epoch)
  — pinned at 1.0.12 + 2 patch commits

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

Patches live on the `cosmic-grid` branch of each submodule checkout.

## Install / Rollback

```bash
sudo ./scripts/install.sh    # backs up stock binaries, replaces, holds packages, installs apt pin
sudo ./scripts/rollback.sh   # restores stock binaries, releases holds, removes pin
```

Installing replaces only `/usr/bin/cosmic-comp` and `/usr/bin/cosmic-workspaces`,
runs `apt-mark hold` on both, and installs `/etc/apt/preferences.d/99-cosmic-grid.pin`
to block accidental upgrades. Log out/in after either.

**Build on ext4, not the `Data` drive** — NTFS silently kills cargo builds.
Use an ext4 working copy (e.g. `~/cosmic-grid-build/`).

## Updates & maintenance

`cosmic-comp` and `cosmic-workspaces` are **manually managed** — everything else
updates normally. Two layers protect the patched binaries:

- `apt-mark hold` — blocks implicit upgrades
- `/etc/apt/preferences.d/99-cosmic-grid.pin` (priority 1002) — blocks **even an
  explicitly-named `apt upgrade cosmic-comp`**, which is what bypasses a hold

Keep in mind:

- **Never** `apt reinstall`/`apt --reinstall install` cosmic-comp or
  cosmic-workspaces — that restores stock files over the patch.
- If an `apt full-upgrade` holds back cosmic packages or errors about a dependency
  wanting a newer `cosmic-comp`, that's the pin working, not a bug.
- The COSMIC Store may still *show* an update for these; apt will refuse it.
- **Build on ext4** (e.g. `~/cosmic-grid-build/`), never on the NTFS `Data` drive.
- A Pop!_OS release upgrade re-checks everything — plan to re-patch afterwards.

Health check:

```bash
apt-mark showhold
ls -l /etc/apt/preferences.d/99-cosmic-grid.pin
```

### Moving to a newer COSMIC on purpose
1. `sudo ./scripts/rollback.sh` (stock back, holds + pin removed).
2. Upgrade COSMIC normally.
3. Re-apply the two patch commits onto the new upstream commit, rebuild on ext4,
   reinstall (resolve any conflicts as upstream evolves).
4. Update the version strings in `scripts/99-cosmic-grid.pin` to the new versions
   before re-running `install.sh`.

Full incident history, the exact recovery playbook, and pending git state are in
[`NOTES.md`](NOTES.md).

## Known limitations (v1)

- Super+Shift+Arrows (move window) still use linear next/previous, not the grid.
- Drag-reorder of workspace cells is disabled; toplevels can still be dragged
  into any cell.
- `workspace_mode: Global` isn't grid-aware (stick with `OutputBound`, the
  default).

## Files

- `README.md` — this file
- `NOTES.md` — project history, maintenance & recovery reference
- `cosmic-comp/` — compositor source, `cosmic-grid` branch
- `cosmic-workspaces/` — overview app source, `cosmic-grid` branch
- `stock/` — archived stock binaries
- `scripts/` — build / install / rollback + apt pin
- `docs/superpowers/specs/` — design spec
