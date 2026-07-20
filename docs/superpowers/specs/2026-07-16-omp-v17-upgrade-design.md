# Design Spec: Upgrade OMP Home Module to v17.0.0

- **Date**: 2026-07-16
- **Status**: Proposed
- **Target File**: `modules/home/omp/default.nix`

## Goal

Align the `omp` Home Manager module with the newly released `oh-my-pi` v17.0.0. Specifically, clean up removed settings (`discoveryMode`, `essentialOverride`) and add new settings (`tools.xdev`, `edit.enforceSeenLines`, and the updated `memory.backend` enum values).

## Changes

### 1. Obsolete Options Cleanup
- Remove `discoveryMode` and `essentialOverride` from `options.omp.tools`.
- Remove `discoveryMode` and `essentialOverride` from the `typedSettings.tools` mapping.

### 2. Add New Settings
- Add `xdevEnabled` to `options.omp.tools` (boolean) to map to `tools.xdev`.
- Add `enforceSeenLines` to `options.omp.files` (boolean) to map to `edit.enforceSeenLines`.
- Update `typedSettings` to map:
  - `tools.xdev` -> `cfg.tools.xdevEnabled`
  - `edit.enforceSeenLines` -> `cfg.files.enforceSeenLines`

### 3. Update Memory Backend Options
- Update the `options.omp.memory.backend` enum to allow: `["off" "local" "hindsight" "mnemopi"]`. This replaces `"none"` with `"off"` and introduces the new `"local"` backend.

## Verification Plan
1. **Formatting**: Run `nix fmt` to format all `.nix` files.
2. **Nix Flake Evaluation**: Run `nix flake check` to ensure that all system and home configurations in this repository continue to evaluate successfully.
