# BakerOS Roadmap

## Versioning

`\{milestone\}.\{feature\}.\{patch\}`

| Segment | Meaning |
| - | - |
| milestone | Big milestone reached |
| feature | New capability shipped |
| patch | Bug fix or minor correction |


| Milestone | Who it's for |
| - | - |
| 1.x.x | the_baker only |
| 2.x.x | Anyone — usable out of the box |
| 3.x.x | Full ncurses TUI (quality of life) |



## Released

### v1.0.0 — Baseline ✓

BakerOS is operational for the_baker. Fresh install of any baker machine works end-to-end. Hardware values are manually entered. Identity is hardcoded in the scripts.

- `install.sh` → `post-install.sh` → `post-reboot.sh` three-script flow

- `configure.sh` — monolithic, idempotent system config

- `upgrade.sh` / `baker-update` — converges live machine to desired state

- the_baker fleet key registry in `keys/` — cross-machine access via Tailscale MagicDNS

- Package manifests in `packages/` — single source of truth for installed software

- `.baker-config` — persistent machine config

### v1.0.1 — Nvidia driver fix ✓

- Switched `nvidia-dkms` → `nvidia-open-dkms` in `install.sh` (open-source kernel modules, recommended for RTX 30xx+)
- Added `linux-headers` to the Nvidia bootstrap packages so DKMS can rebuild the module on kernel upgrades


## Planned

### v1.1.0 — Hardware Detection

**Detail:** `phase-v1.1.0.md`

Auto-detect GPU, CPU brand, profile, available disks, timezone, and dual-boot hint at the top of `install.sh`. Detected values pre-fill prompts; the_baker can still override. No UI overhaul — that comes in v1.2.0. Pure quality-of-life for the_baker right now.

- `packages/gpu-nvidia.txt`, `packages/gpu-amd.txt`, `packages/gpu-intel.txt` — GPU hardware axis for the manifest system. `upgrade.sh` reads `.baker-config`’s `GPU` value and installs from the matching file, same pattern as `PROFILE` → `workstation.txt`/`laptop.txt`. Keeps GPU-specific packages (drivers, headers) tracked and synced by `baker-update`.

### v1.2.0 — the_baker/User Split

**Detail:** `phase-v1.2.0.md`

Separate the_baker identity from BakerOS core. After this a regular user can run `install.sh` and get a quality Arch install with their own choices. the_baker steps only run when the the_baker token is entered at install time.

- `the_baker.conf` — the_baker identity, repo URLs, token hash, install defaults

- the_baker mode / user mode — token gates the_baker-specific steps

- `packages/the_baker.txt` — the_baker taste packages, installed only in the_baker mode

- `.baker-config` renamed to `.baker_config` — consistent with underscore convention for config files

- Suggest-and-override bash UI throughout `install.sh` — clean, consistent

- Custom package URL support

- Post-install/post-reboot/upgrade gated on service flags in `.baker_config`

### v1.3.0 — Configure Split + Server Guards

**Detail:** `phase-v1.3.0.md`

Break `configure.sh` into focused sub-scripts and add server profile guards throughout. Pure structural work — no user-facing behaviour change. Prerequisite for v1.4.0.

- `configure.sh` becomes a thin orchestrator

- Sub-scripts: `configure-system.sh`, `configure-boot.sh`, `configure-gpu.sh`, `configure-network.sh`, `configure-desktop.sh`, `configure-power.sh`, `configure-storage.sh`

- Server guards in `post-install.sh` and `upgrade.sh` — sddm, NordVPN, Flatpak, pipewire, desktop dotfiles all gated on `PROFILE != server`; ready for ringbaker before it's built

### v1.4.0 — Hardware-Aware Dotfiles + READMEs → declares v2.0.0

**Detail:** `phase-v1.4.0.md`

Baker generates small machine-specific config files; dotfiles source a single stable entry point. Dotfiles repo stays hardware-agnostic. READMEs written for a public audience.

- `baker-hardware.conf` (environment.d), `baker.conf`, `hardware.conf`, `monitors.conf`

- `baker-gpu.sh` and `baker-battery.sh` Waybar scripts (absent when hardware doesn't apply)

- `baker/README.md` — full user-facing docs

- `dotfiles/README.md` — baker compatibility, the one source line, waybar module names

**v2.0.0 declaration:** bump VERSION to `2.0.0` once v1.4.0 is verified on nomadbaker and pearlybaker. No additional work required.


## Future

### v3.0.0 — TUI

Replace enhanced bash prompts with a proper ncurses TUI using whiptail/dialog. The suggest-and-override pattern from v1.2.0 maps directly to whiptail `--menu` and `--inputbox` — migration, not redesign.


## Parking Lot

| Item | Notes |
| - | - |
| ringbaker server packages | Design `packages/server.txt` when hardware exists |
| ringbaker raidz2 storage | Pool creation, dataset layout — design when hardware exists |
| NordVPN + Tailscale killswitch coexistence | Known conflict; tracked in memory |
| ollama on workstation | Add to `packages/workstation.txt` when ready |
| shellcheck CI | GitHub Actions lint job on every push |


