# BakerOS v1.1.0 — Hardware Detection

Auto-detect GPU, CPU, profile, disks, timezone, and dual-boot hint at the top of
`install.sh`. Detected values pre-fill the existing prompts. Owner can still override
anything. No UI overhaul — that comes in v1.2.0. Pure quality-of-life for the owner.

Git branch: `feature/hardware-detection`
Delete when done.

---

## What gets auto-detected

| Value | Method |
|---|---|
| **GPU** | `lspci \| grep -iE 'vga\|3d\|display'` → `nvidia` / `amd` / `none` |
| **CPU brand** | `grep -m1 vendor_id /proc/cpuinfo` → `GenuineIntel` / `AuthenticAMD` → ucode package |
| **Profile** | `/sys/class/dmi/id/chassis_type` → see table below |
| **Available disks** | `lsblk -d -n -o NAME,SIZE,TYPE \| grep disk` |
| **Secondary HDD** | additional disks beyond install target |
| **Dual boot hint** | `efibootmgr` → Windows Boot Manager entry present |
| **Timezone** | `curl -s ipinfo.io/timezone` |

### Chassis type → profile mapping

| DMI chassis values | Profile |
|---|---|
| 8, 9, 10, 14 | `laptop` |
| 3, 4, 5, 6, 7, 13, 15, 16 | `workstation` |
| 17, 23, 24, 28, 29 | `server` |
| anything else | `unknown` → prompt with no suggestion |

VMs, mini PCs, and unusual hardware often report "Other" or "Unknown" — the unknown
fallback handles this gracefully.

## What still needs user input

| Value | Reason |
|---|---|
| Which disk to install to | Never auto-select — wrong disk = data loss |
| Hostname | Machine-specific, cannot be inferred |
| LUKS yes/no | Security preference |
| Dual boot confirm | Even if Windows detected, user confirms intent |
| Username / locale / keymap | Personal choices |

---

## What changes

### `install.sh`

Add a hardware detection block at the very top, before any interactive prompts.
Detected values stored in local variables (`DETECTED_GPU`, `DETECTED_PROFILE`, etc.)
and used to pre-fill the existing prompt strings.

Keep the existing prompt flow — just swap hardcoded defaults for detected values.
No new UI patterns yet. If detection fails for a field, fall back to the current
prompt with no pre-fill.

### Nothing else changes

`post-install.sh`, `post-reboot.sh`, `configure.sh`, `upgrade.sh` — untouched.

---

## Implementation order

1. Detection block (GPU, CPU, profile, timezone)
2. Disk listing (replace the current bare prompt with `lsblk` output)
3. Secondary HDD detection
4. Dual boot hint from `efibootmgr`
5. Wire detected values into existing prompt strings
