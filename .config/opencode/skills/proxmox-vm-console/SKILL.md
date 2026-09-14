---
name: proxmox-vm-console
description: >
  Drive a Proxmox VM's graphical console headlessly — capture screenshots,
  send keystrokes/typed text, and move/click a pointer — without noVNC in a
  browser. Use when you must see what's on a VM's screen and interact with a
  GUI/installer/console you cannot reach any other way (no adb, no SSH into the
  guest). Builds on `proxmox-api`.
---

## Driving a VM console headlessly

You do **not** drive the noVNC web client. You drive the same input plane it
sits on, via three layers:

1. **HMP `sendkey` + `screendump`** (keyboard + screen) — through the Proxmox
   `/monitor` API. This is the low-footprint default and needs only the API +
   SSH to the host.
2. **QMP `input-send-event`** (absolute pointer / taps) — via the host's
   `/var/run/qemu-server/{vmid}.qmp` unix socket over SSH. Needed for mouse.
3. Real VNC/RFB over `vncproxy` + `vncwebsocket` — heavier; rarely needed.

### Prerequisites

- Env: `PVE_HOST PVE_NODE PVE_USER PVE_PASS` and `PVE_VMID`, plus the guest
  framebuffer size `PVE_W`/`PVE_H` (e.g. 1024x768 — read it off a screenshot).
- SSH to the **host** as root (screendump writes a file on the host that you
  pull back). `pip install paramiko pillow` locally.
- The guest needs a USB **tablet** for absolute pointer coords — it's on by
  default in Proxmox unless the config has `tablet: 0`.

### The read → decide → act loop

- **Screenshot**: `python3 scripts/pvedrive.py shot out.png`
  (HMP `screendump /tmp/vmshot.ppm` on the host → SFTP the PPM → Pillow → PNG).
  Then use OpenCode's `read` tool to inspect the PNG.
- **Keys**: `pvedrive.py keys down down ret` — each arg is a QEMU keysym or a
  chord joined with `-` (`ctrl-alt-f1`, `shift-a`). Common: `up down left
  right ret esc tab spc`, letters `a`-`z`, digits, `f1`..`f12`.
- **Type text**: `pvedrive.py line "settings put secure user_setup_complete 1"`
  handles uppercase (shift), digits, and symbols via a char→keysym map.
- **Pointer** (needs `scripts/qmpclick.py` on the host): `pvedrive.py tap X Y`
  / `pvedrive.py move X Y` in *pixel* coords; it scales to QEMU's 0–32767 abs
  range using `PVE_W`/`PVE_H`.

Always screenshot after each action and verify before the next — menus/focus
behave differently than you expect (see gotchas).

### Hard-won gotchas

- **newt/whiptail installer dialogs**: the highlighted `<OK>` button is the
  focused default — `ret` activates it. `tab` moves focus (often OK→Cancel);
  arrow keys move the *list selection* independently. If `ret` "does nothing",
  the action may be silently failing (e.g. cfdisk on a blank disk), not a lost
  keystroke — verify with a screenshot before mashing keys.
- **Text-console blanking**: a Linux VT blanks after idle; a *keypress* wakes
  it (pointer does not).
- **GUI display sleep**: an Android/X GUI blanks on idle; a *pointer move/tap*
  wakes it (keyboard often does not). Send a `move` first, then screenshot.
- **VT switching corrupts the GUI**: once a GUI compositor (SurfaceFlinger/X)
  has fully taken KMS, switching to a text VT (`ctrl-alt-f1`) and back
  (`ctrl-alt-f7`) frequently leaves the screen **black** and unrepaintable by
  input. Do console work in *one* VT visit, or better, enable adb/SSH so you
  never switch. A **reboot** restores the display cleanly.
- **Not every black screen is suspend**: check `pve.py status` — `qmpstatus`
  is still `running`. Only if the guest is genuinely S3-suspended does HMP
  `system_wakeup` help (it errors "guest is not in suspended state"
  otherwise). Android-x86 can suspend-to-RAM on idle; disable sleep in it.
- **Screenshots always reflect the framebuffer**, even a black/garbled one —
  a black shot ≠ crashed guest. Confirm liveness via CPU%/uptime.

### Scripts

- `scripts/pvedrive.py` — self-contained (stdlib + paramiko + pillow): `shot`,
  `keys`, `type`, `line`, `move`, `tap`, plus `keys ctrl-alt-f1` for VT switch.
- `scripts/qmpclick.py` — runs **on the host**; pvedrive uploads it and calls
  it over SSH to talk to the QMP socket for pointer events. You can also run it
  directly on the host: `qmpclick.py <vmid> <W> <H> tap X Y`.
