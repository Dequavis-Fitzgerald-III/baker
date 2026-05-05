# BakerOS v1.3.0 — Configure Split + Server Guards

Break `configure.sh` into focused sub-scripts and add server profile guards throughout
the install and upgrade flow. Pure structural work — no user-facing behaviour change.
Prerequisite for v1.4.0 which adds new sub-script responsibilities.

Git branch: `feature/configure-split`
Delete when done.

---

## 1. Break up configure.sh

`configure.sh` currently does too many jobs. Split it into focused sub-scripts.
`configure.sh` becomes a thin orchestrator that reads `.baker-config` and calls the
right sub-scripts. External interface (`install.sh` and `upgrade.sh` both call
`configure.sh`) is unchanged. Each sub-script is safe to call standalone for debugging.

```
configure.sh                 ← orchestrator only
  configure-system.sh        ← hostname, locale, timezone, keymap, sshd       [ALL profiles]
  configure-boot.sh          ← mkinitcpio hooks, GRUB                         [ALL profiles]
  configure-gpu.sh           ← Nvidia/AMD services, kernel params              [GPU != none]
  configure-network.sh       ← wifi credentials/config                        [laptop only]
  configure-desktop.sh       ← sddm, hyprland-welcome removal                 [workstation + laptop]
  configure-power.sh         ← tlp / auto-cpufreq                             [laptop only]
  configure-storage.sh       ← secondary HDD mount point                      [HDD=true]
```

### What moves where

| Current section in configure.sh | Moves to |
|---|---|
| Timezone | configure-system.sh |
| Locale | configure-system.sh |
| Console keymap | configure-system.sh |
| Hostname + /etc/hosts | configure-system.sh |
| Sudo | configure-system.sh |
| sshd hardening drop-in | configure-system.sh |
| mkinitcpio HOOKS + rebuild | configure-boot.sh |
| GRUB cmdline + timeout + dual boot + grub-mkconfig | configure-boot.sh |
| Hyprland-welcome removal | configure-desktop.sh |
| HDD mount point | configure-storage.sh |

### New stubs (empty for now, filled in v1.4.0)

`configure-gpu.sh` — placeholder, no logic yet
`configure-network.sh` — placeholder, no logic yet
`configure-power.sh` — placeholder, no logic yet

These exist so the orchestrator can call them unconditionally and the v1.4.0 work
slots in without touching configure.sh again.

---

## 2. Server profile guards

ringbaker (not yet built) is server profile: no desktop, no NordVPN, Tailscale-only,
SSH-only access. Guards must be in place before it's built.

### post-install.sh guards

| Step | Guard condition |
|---|---|
| sddm install + enable | `PROFILE != server` |
| NordVPN install + login | `PROFILE != server` |
| Flatpak install + packages | `PROFILE != server` |
| pipewire user service | `PROFILE != server` |
| Desktop dotfiles symlinks | `PROFILE != server` |
| Wifi credential setup | `PROFILE = laptop` |

### upgrade.sh guards

| Step | Guard condition |
|---|---|
| Flatpak packages | `PROFILE != server` |
| NordVPN check | `PROFILE != server` |

### configure.sh orchestrator guards

| Sub-script | Guard condition |
|---|---|
| configure-desktop.sh | `PROFILE != server` |
| configure-network.sh | `PROFILE = laptop` |
| configure-power.sh | `PROFILE = laptop` |
| configure-gpu.sh | `GPU != none` |
| configure-storage.sh | `HDD = true` |

### What server still gets

- configure-system.sh (hostname, locale, sshd)
- configure-boot.sh (mkinitcpio, GRUB)
- configure-gpu.sh (when hardware exists)
- configure-storage.sh (HDD mount — raidz2 is a separate future task)
- Base packages, yay, AUR packages
- Tailscale

---

## Implementation order

1. Write `configure-system.sh` — extract timezone, locale, keymap, hostname, sudo, sshd
2. Write `configure-boot.sh` — extract mkinitcpio + GRUB sections
3. Write `configure-desktop.sh` — extract hyprland-welcome removal
4. Write `configure-storage.sh` — extract HDD mount section
5. Write empty stubs: `configure-gpu.sh`, `configure-network.sh`, `configure-power.sh`
6. Rewrite `configure.sh` as thin orchestrator with profile/GPU guards
7. Add server guards to `post-install.sh`
8. Add server guards to `upgrade.sh`
9. Smoke test: run `configure.sh` on nomadbaker and pearlybaker — verify no behaviour change
