# MojOS Architecture Shift

This document captures the architectural decisions made before implementing v1.2.0.
It supersedes the original `phase-v1.2.0.md` plan.

---

## The Problem With the Current Design

The current `baker` repo is two things tangled together:
- The OS framework (install scripts, upgrade system, package manifests)
- the_baker's personal fleet config (identity, packages, keys)

This makes it impossible to share MojOS with others without exposing personal config,
and impossible to keep personal config without forking a repo that was never designed for it.

---

## The New Model: Two Repos

### MojOS — `mojos` (public)

The OS framework. Named after Mojo. Anyone can fork it.
Contains everything needed to build a personalised Arch Linux system.
No personal config, no identity, no keys.

GitHub: `github.com/Dequavis-Fitzgerald-III/mojos` (current `baker` repo renamed)

**What lives here:**
- `install.sh`, `configure.sh`, `upgrade.sh`, `post-install.sh`, `post-reboot.sh`
- `mojo-init.sh` — fork setup script
- `sync-keys.sh` — fleet key registry rebuild
- `packages/base.txt`
- `packages/profile/` — workstation, laptop, server
- `packages/hardware/` — gpu-nvidia, gpu-amd, gpu-intel
- `packages/user/` — empty, populated by each fork via `mojo-init.sh`

**What does NOT live here:**
- Any `$name.conf`
- Any `packages/user/$name.txt`
- Any `keys/`
- Any personal defaults

---

### BakerOS — `baker` (private, the_baker's fork)

the_baker's personal fleet. Private GitHub repo. Fork of MojOS.
Contains the_baker's identity, packages, and fleet keys.
Only ever adds files — never modifies MojOS framework files.

GitHub: `github.com/Dequavis-Fitzgerald-III/baker` (new private repo, forked from mojos)

**Additions only:**
- `the_baker.conf` — identity and defaults
- `packages/user/the_baker.txt` — the_baker's personal packages
- `keys/` — fleet SSH public keys
- `authorized_keys` — rebuilt from keys/

---

## Naming Conventions

| Context | Name |
|---|---|
| Public OS framework | MojOS |
| Public repo slug | `mojos` |
| Framework update command | `mojo-update` |
| Framework config file on machine | `.mojo_config` |
| Fork setup script | `mojo-init.sh` |
| User identity variable | `BAKER_USER` |
| User conf file | `$BAKER_USER.conf` |
| User packages | `packages/user/$BAKER_USER.txt` |
| the_baker's fleet name | BakerOS |
| the_baker's repo slug | `baker` |

No fork gets special behaviour not available to all users.
the_baker's fork is a configured instance of MojOS, not a modified one.

---

## `mojo-init.sh`

Run once after forking MojOS on an existing machine with `git` and `gh` installed.
Turns a blank fork into a personalised OS.

**What it does:**
1. Auto-detects fork remote URL from `git remote get-url origin`
2. Sets `BAKER_USER=$name` at the top of `install.sh`
3. Collects identity defaults:
   - Name → becomes `BAKER_USER`
   - Username
   - Timezone
   - Locale
   - Keymap
   - Dotfiles URL
4. Writes `$name.conf`
5. Opens `$EDITOR` on `packages/user/$name.txt` — user adds personal packages
6. Adds `upstream` remote pointing to `github.com/Dequavis-Fitzgerald-III/mojos`
7. Commits and pushes everything to the fork
8. Generates a GitHub PAT via `gh` (or guides through manual creation if `gh` unavailable)
9. Prints the complete install command:

```
Your install command (save this):

git clone https://ghp_xxxx@github.com/username/baker.git && bash baker/install.sh
```

---

## Install Flow

User boots Arch ISO and runs their install command. `install.sh`:

1. Reads `BAKER_USER` (set by `mojo-init.sh` at the top of the script)
2. Reads `$BAKER_USER.conf` for identity defaults
3. **Phase 1** — hardware detection (unchanged from v1.1.0)
4. **Phase 2** — interactive prompts, pre-filled from `$BAKER_USER.conf` and detection
5. **Phase 3** — fully unattended install

All files read locally — no mid-install curling. Everything is in the cloned fork.
`REPO_RAW` and all curl calls are removed from `install.sh`.

---

## `mojo-update`

Run on any live MojOS machine to converge to the latest desired state.

**New step — upstream sync (runs first):**
```bash
# Self-healing upstream remote
git -C "$MOJO_DIR" remote get-url upstream &>/dev/null \
    || git -C "$MOJO_DIR" remote add upstream https://github.com/Dequavis-Fitzgerald-III/mojos.git

git -C "$MOJO_DIR" fetch upstream
git -C "$MOJO_DIR" merge upstream/main
git -C "$MOJO_DIR" push origin
```

Forks only ever add files — MojOS framework files are never modified by a fork.
Merges are always clean. New base/profile/hardware packages added upstream
flow automatically to all forks on next `mojo-update`.

The upstream remote is set by `mojo-init.sh` and self-healed by `mojo-update` if missing.

---

## Fleet SSH Registry

Standard MojOS feature available to all users. Single-machine users have a one-key
registry — that is fine and fully supported.

- `install.sh` registers `keys/$hostname.pub` and commits + pushes to the fork
- `authorized_keys` and `~/.ssh/config` rebuilt from all `.pub` files in `keys/`
- `mojo-update` runs `sync-keys.sh` on every run
- New machines join the fleet automatically via `install.sh`

---

## `.mojo_config`

Replaces `.baker-config` on all machines. Same structure, same purpose.
Written by `install.sh`, read by `mojo-update` and `configure.sh`.

New fields added in v1.2.0:
```bash
BAKER_USER=the_baker     # which user conf was used at install time
```

---

## Migration Plan

1. **Commit current work** — package reorganisation, pending changes
2. **Rename `baker` → `mojos`** on GitHub (Settings → Rename)
3. **Implement v1.2.0 on `mojos`:**
   - Rename all `baker-*` references to `mojo-*` in framework files
   - Remove `REPO_RAW` and all mid-install curl calls from `install.sh`
   - Add `BAKER_USER` variable and `$name.conf` system
   - Write `mojo-init.sh`
   - Implement `mojo-update` upstream sync
   - Rename `.baker-config` → `.mojo_config` throughout
4. **Fork `mojos` → private `baker`**
5. **Run `mojo-init.sh`** to generate `the_baker.conf` and `packages/user/the_baker.txt`
6. **Migrate `keys/`** from current repo to the private fork
7. **Update machines** — nomadbaker and pearlybaker
