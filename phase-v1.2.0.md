# BakerOS v1.2.0 — Personal Split

Separate fleet owner identity from BakerOS core. After this version a regular user can
run `install.sh` and get a high-quality Arch install with their own choices. Fleet-specific
steps (SSH key registry, NordVPN, Tailscale joining owner's tailnet) only run when the
fleet token is entered at install time.

Hardware auto-detection is already in place from v1.1.0. This version adds the full
suggest-and-override UI on top of those detected values, and the owner/regular mode split.

Git branch: `feature/personal-split`
Delete when done.

---

## Design Philosophy

Baker is a well-paved road, not a walled garden. Opinionated defaults for everything —
but the escape hatch is always there. Friends who want their own fleet: fork the repo,
set up `fleet.conf`, generate their own token. Their fork IS their fleet.

---

## The Model: Two Modes

**Owner mode** — correct fleet token entered at install time:
- All hardware already detected (v1.1.0), all personal defaults pre-filled from `fleet.conf`
- Machine registered in fleet key registry
- SSH `authorized_keys` rebuilt from all fleet keys
- `~/.ssh/config` populated with all fleet hostnames via Tailscale MagicDNS
- GitHub configured with owner's SSH key, pushed to baker repo
- Tailscale joins owner's tailnet
- NordVPN set up (if not server profile)
- Goal: ~5 inputs total, mostly one keystroke each

**Regular user mode** — no token entered:
- Hardware auto-detected (same benefit as owner)
- No personal defaults — all prompts show suggestions but nothing pre-filled with owner values
- Each identity step is a simple prompt — fleet steps never mentioned
- Result: a quality Arch install with their own choices

---

## Suggest-and-Override UI

Every auto-detected or defaulted value follows the same pattern.
The suggestion is shown clearly; pressing Enter accepts it; typing overrides it.

```
  GPU       → nvidia  (NVIDIA GeForce RTX 3080)
  CPU       → intel   (Intel Core i9-12900K)
  Profile   → workstation  (Desktop chassis)

  Press Enter to accept, or type a field name to change it:  _
```

For fields with fixed options:

```
  Profile detected: workstation  (Desktop chassis)
  [Enter] Accept   [1] laptop   [2] workstation   [3] server   > _
```

For free-text fields with a suggestion:

```
  Timezone detected: Europe/London  (via IP)
  [Enter] Accept   or type to override:  _
```

For disk selection (always shown as a list, never auto-picked):

```
  Disks available:
    1)  nvme0n1   1 TB    NVMe SSD
    2)  sda       2 TB    HDD

  Install target:  _
```

### Install sections

Hardware Detection → Install Target → Encryption → Identity → Packages → Confirmation.
Each section uses the existing `section` colour helper.

---

## fleet.conf

Committed to the baker repo. Not secret — the token hash gates access, not the values.
Regular users who fork replace these with their own values.

```bash
# fleet.conf

FLEET_OWNER_GITHUB=Dequavis-Fitzgerald-III
FLEET_BAKER_REPO=github.com/Dequavis-Fitzgerald-III/baker
FLEET_PACKAGES_URL=raw.githubusercontent.com/Dequavis-Fitzgerald-III/baker/main/packages
FLEET_DOTFILES_URL=github.com/Dequavis-Fitzgerald-III/dotfiles
FLEET_TAILNET=circus-tent
FLEET_TOKEN_HASH=<sha256sum of owner's secret passphrase>

# Owner install defaults (pre-filled in owner mode, invisible to regular users)
OWNER_USERNAME=clarkehines
OWNER_TIMEZONE=Europe/London
OWNER_LOCALE=en_GB.UTF-8
OWNER_KEYMAP=uk
OWNER_NORD_COUNTRY=us
```

Hostname is NOT in fleet.conf — always prompted because it is machine-specific.

Generating the token hash (run once, paste output into fleet.conf):
```bash
echo -n "your secret passphrase" | sha256sum | awk '{print $1}'
```

---

## Packages

Baker's package lists are a public default available to any user. During install every
user is offered Baker packages as the default:

```
  Package list:
    Baker default  (packages/base.txt + profile packages)
  [Enter] Use Baker packages   [c] Use custom URL   > _
```

`PACKAGES_URL` is written to `.baker-config` and used by `upgrade.sh` on every update.
In `fleet.conf`, `FLEET_PACKAGES_URL` points to the owner's repo so forks pull from
their own packages, not the original baker repo.

---

## Install flows

### Owner mode (~5 inputs)

```
[Hardware Detection]   ← detected in v1.1.0, shown with accept-all prompt

[Fleet Token]
  Token: ******  → owner mode activated, defaults loaded from fleet.conf

[Install Target]
  1) nvme0n1  1TB  NVMe  ←
  Install target [1]: _

[Encryption]
  Encrypt with LUKS? [Y/n]: _

[Identity]
  Hostname: _           ← only thing owner always types

[Dual Boot]             ← only appears if Windows detected
  Windows detected — dual boot? [y/N]: _

[Confirmation]
  → show all values → proceed → fully unattended
```

### Regular user mode

```
[Hardware Detection]   ← detected values shown with suggest-and-override UI

[Fleet Token]
  Fleet token (press Enter to skip): _   → regular user mode

[Install Target]
  1) nvme0n1  512GB  NVMe
  Install target [1]: _

[Encryption]
  Encrypt with LUKS? [Y/n]: _

[Identity]
  Hostname: _
  Username: _
  Timezone (detected: America/New_York) [Enter to accept or type]: _
  Locale (e.g. en_US.UTF-8): _
  Keymap (e.g. us): _

[Dual Boot]             ← only appears if Windows detected
  Windows detected — dual boot? [y/N]: _

[Packages]
  [Enter] Use Baker packages   [c] Custom URL: _

[Dotfiles]
  Use a dotfiles repo? [y/N]: _   → if yes: URL: _

[Services]
  Set up GitHub SSH? [y/N]: _
  Set up Tailscale?  [y/N]: _
  Install NordVPN?   [y/N]: _

[Confirmation]
  → show all values → proceed → fully unattended
```

---

## .baker-config additions

```bash
FLEET_OWNER=true|false
PACKAGES_URL=<url>
DOTFILES_URL=<url>
GITHUB_SETUP=true|false
TAILSCALE_SETUP=true|false
NORDVPN_SETUP=true|false
```

---

## What changes in each script

### install.sh

- Fetch `fleet.conf` from repo at top of script
- Token prompt: correct → owner mode, load fleet.conf defaults; skipped → regular mode
- Owner mode: skip identity prompts, pre-fill from fleet.conf
- Regular mode: suggest-and-override UI on all fields + yes/no for each service
- Write new `.baker-config` fields

### post-install.sh

Owner mode (`FLEET_OWNER=true`):
- Push SSH key to `keys/<hostname>.pub`, commit + push to baker repo
- Rebuild `authorized_keys` + `~/.ssh/config` from all fleet keys
- Configure git SSH rewrite to `FLEET_BAKER_REPO`

Regular user mode (`FLEET_OWNER=false`):
- If `GITHUB_SETUP=true`: generate key, add to user's own GitHub
- No fleet registry, no fleet SSH config

### post-reboot.sh

- `TAILSCALE_SETUP=true` → `tailscale up`
- `NORDVPN_SETUP=true` + `PROFILE != server` → NordVPN login
- Anything false → skip silently

### upgrade.sh

- `FLEET_OWNER=true` → run `sync-baker-keys.sh`
- Pull packages from `PACKAGES_URL` (from `.baker-config`)
- Pull dotfiles from `DOTFILES_URL` (from `.baker-config`)

---

## What stops being hardcoded

| Value | Before | After |
|---|---|---|
| GitHub org/username | hardcoded | fleet.conf (owner) / prompted (regular) |
| Baker repo URL | hardcoded | `FLEET_BAKER_REPO` in fleet.conf |
| Packages URL | hardcoded | fleet.conf default; user can override |
| Dotfiles URL | prompted (no default) | fleet.conf default (owner) / prompted (regular) |
| Tailnet name | hardcoded `circus-tent` | fleet.conf (owner) / prompted (regular) |

---

## Implementation order

1. Write `fleet.conf`
2. Update `install.sh`:
   a. fleet.conf fetch
   b. Token prompt + mode branching
   c. Owner mode: load defaults, minimal prompts
   d. Regular mode: suggest-and-override UI on all fields
   e. Packages section (Baker default vs custom URL)
   f. Write new `.baker-config` fields
3. Update `post-install.sh` — gate steps on `FLEET_OWNER` and service flags
4. Update `post-reboot.sh` — gate Tailscale and NordVPN on flags
5. Update `upgrade.sh` — use `PACKAGES_URL` and `DOTFILES_URL`; gate fleet sync
