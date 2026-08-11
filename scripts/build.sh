#!/usr/bin/env bash
# Build patched cosmic-comp and cosmic-workspaces (release).
# Run from the cosmic-grid project root.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Building cosmic-comp (patched)..."
cargo build --release --manifest-path cosmic-comp/Cargo.toml
echo "==> Building cosmic-workspaces (patched)..."
cargo build --release --manifest-path cosmic-workspaces/Cargo.toml

echo
echo "Built binaries:"
ls -lh cosmic-comp/target/release/cosmic-comp
ls -lh cosmic-workspaces/target/release/cosmic-workspaces
echo
echo "Done. Install with:  sudo ./scripts/install.sh"
