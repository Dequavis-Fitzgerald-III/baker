# BakerOS v1.4.0 — Hardware-Aware Dotfiles + READMEs

Baker generates small machine-specific config files; dotfiles source a single stable
entry point. Dotfiles repo stays hardware-agnostic and works for any BakerOS user.
READMEs written for a public audience. Declaring v2.0.0 once this ships.

Builds on v1.3.0 (configure-split) — `configure-desktop.sh`, `configure-gpu.sh`,
`configure-network.sh`, and `configure-power.sh` get their actual logic here.

Git branch: `feature/hardware-dotfiles`
Delete when done.

---

## The Problem

Dotfiles are static files. Some Hyprland and Waybar config must vary by GPU and profile
(e.g. Nvidia env vars, monitor layout, battery widget only on laptop). Dotfiles repo
should stay hardware-agnostic and work for any BakerOS user.

---

## Solution: baker generates, dotfiles source

Baker generates small hardware-specific files via `configure-desktop.sh`.
Dotfiles source or reference them. The dotfiles repo never needs to know about hardware.

### What baker generates

```
~/.config/environment.d/baker-hardware.conf   ← systemd user env vars (auto-sourced by PAM)
~/.config/hypr/baker.conf                     ← stable entry point sourced by dotfiles
~/.config/hypr/hardware.conf                  ← Hyprland-specific directives (cursor etc.)
~/.config/hypr/monitors.conf                  ← monitor layout (machine-specific)
~/.config/waybar/scripts/baker-gpu.sh         ← GPU data script (absent on Intel)
~/.config/waybar/scripts/baker-battery.sh     ← battery data script (absent on desktop/server)
```

`baker.conf` is the stable entry point — its internals can grow without the dotfiles
convention ever changing.

### Environment variables by GPU

**Nvidia** — `baker-hardware.conf`:
```bash
LIBVA_DRIVER_NAME=nvidia
XDG_SESSION_TYPE=wayland
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
```

**Nvidia** — `hardware.conf`:
```
cursor {
    no_hardware_cursors = true
}
```

**AMD** — `baker-hardware.conf`:
```bash
LIBVA_DRIVER_NAME=radeonsi
XDG_SESSION_TYPE=wayland
```

**Intel (none)** — `baker-hardware.conf`:
```bash
XDG_SESSION_TYPE=wayland
```

### Waybar: baker owns data, dotfiles own layout

Baker generates shell scripts that waybar custom modules execute. Dotfiles reference
the module names wherever the user wants them. If a script is absent (e.g. no discrete
GPU), the module silently produces nothing.

---

## The Baker Dotfiles Convention

One source line in `hyprland.conf` is the entire contract:

```bash
# hyprland.conf
source = ~/.config/hypr/baker.conf
```

Optional waybar module references (place wherever you want hardware widgets):
```jsonc
"custom/baker-gpu"      // GPU temp/util — present on Nvidia/AMD, empty on Intel
"custom/baker-battery"  // Battery — present on laptop, empty on desktop/server
```

Friends using BakerOS with their own dotfiles add one line. Users forking the baker
dotfiles repo get it already present.

---

## configure-desktop.sh

Generates all baker hardware files based on `GPU` and `PROFILE` from `.baker-config`.
Called by the configure.sh orchestrator for `workstation` and `laptop` profiles.

Logic:
1. Write `baker-hardware.conf` — env vars based on GPU value
2. Write `hardware.conf` — Hyprland directives based on GPU value
3. Write `monitors.conf` — machine-specific layout (placeholder on first run; user edits)
4. Write `baker.conf` — sources `hardware.conf` and `monitors.conf`
5. Write `baker-gpu.sh` — if `GPU != none`; absent otherwise
6. Write `baker-battery.sh` — if `PROFILE = laptop`; absent otherwise

All writes are idempotent — re-running `configure.sh` regenerates these files safely.

---

## configure-gpu.sh

Enable/disable GPU-specific services and kernel parameters.

**Nvidia:**
- Enable `nvidia-persistenced` and `nvidia-powerd`
- Ensure `nvidia-drm.modeset=1` is in GRUB cmdline (idempotent — configure-boot.sh owns the file)

**AMD:**
- No extra services needed

**None:**
- No-op

---

## configure-network.sh

Laptop wifi credential handling extracted from `post-install.sh`. Only runs on laptop.
Manages saved wifi credentials for networks the machine connects to during install.

---

## configure-power.sh

Install and configure power management for laptop profile.

- `tlp` — battery charge thresholds, USB autosuspend
- `auto-cpufreq` if preferred over tlp

---

## READMEs

### baker/README.md (replace current stub)

- What BakerOS is, who it's for
- Fleet overview (machines, profiles, tailnet)
- Install flow: the three-script sequence
- Step-by-step: how to install on a new machine
- Owner mode vs regular user mode
- `baker-update` — what it does, when to run it
- `.baker-config` reference (editable vs auto-detected fields)
- Package manifests — how to add a package
- The baker dotfiles convention (the one source line, the waybar module names)
- Keys registry — how fleet SSH works
- How to fork baker for your own fleet

### dotfiles/README.md (new file in dotfiles repo)

- "This dotfiles repo is baker-compatible"
- The one `source =` line to add to `hyprland.conf`
- The waybar custom module names and what they do
- What baker generates and where (so users know not to put those files in their dotfiles)

---

## Implementation order

1. `configure-desktop.sh` — hardware file generation (baker-hardware.conf, baker.conf, hardware.conf, monitors.conf)
2. `configure-desktop.sh` — waybar scripts (baker-gpu.sh, baker-battery.sh)
3. `configure-gpu.sh` — Nvidia service management and kernel param
4. `configure-network.sh` — extract wifi config from post-install.sh
5. `configure-power.sh` — tlp/auto-cpufreq for laptop
6. `baker/README.md` — rewrite
7. `dotfiles/README.md` — new file in dotfiles repo
8. Verify on nomadbaker (laptop, Intel) and pearlybaker (workstation, Nvidia)
9. Bump VERSION to `2.0.0`
