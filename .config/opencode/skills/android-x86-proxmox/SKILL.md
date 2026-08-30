---
name: android-x86-proxmox
description: >
  Install and set up Android-x86 in a Proxmox VM end to end — create the VM,
  work around the installer's blank-disk quirk, drive the graphical installer,
  bypass the out-of-box setup wizard, and get networking + adb working. Use
  when the user wants an Android VM on Proxmox, or to install/boot/debug
  Android-x86 there. Builds on `proxmox-api` and `proxmox-vm-console`.
---

## Android-x86 on Proxmox — full runbook

Latest official image: **Android-x86 9.0-r2** (Android 9). Newer *modern*
Android in a VM → use **Bliss OS** instead (Android 14/15). Some Android-x86
builds ship Google SetupWizard/GMS (affects OOBE — see below).

### 1. Create the VM (known-good for Android-x86)

Deliberately conservative devices — virtio-gpu/virtio-net misbehave here:

- Machine **i440fx + SeaBIOS** (not q35/UEFI), `ostype=l26`, `cpu=host`
- 4096 MB RAM, 2 cores, `scsihw=virtio-scsi-single`, `scsi0=local-lvm:16`
- **`net0=e1000`** (not virtio), **`vga=std`**, tablet on (default → abs pointer)
- `ide2=local:iso/<android-iso>,media=cdrom`, `boot=order=ide2;scsi0`

Download the ISO straight to the node with `download-url` (see `proxmox-api`).

### 2. THE blank-disk quirk (biggest gotcha)

Android-x86's bundled **cfdisk refuses to open a disk with no partition
table** — "Create/Modify partitions" → OK just silently returns to the
partition picker, and no keystroke sequence gets past it. Fix by writing a
partition table from the **host** while the VM is **stopped**:

```bash
# on the Proxmox host, VM off; disk is the LVM volume for scsi0
printf 'label: dos\n,,L,*\n' | sfdisk /dev/pve/vm-<VMID>-disk-0
```

("re-reading partition table failed" is harmless while off.) Start the VM;
the installer's partition list now shows `sda1`.

### 3. Drive the installer (layer-1 keys, via `proxmox-vm-console`)

GRUB: `down down ret` selects "Installation". Then, screenshotting each step:
select **sda1** → filesystem **ext4** → format **Yes** → install GRUB **Yes**
→ (EFI GRUB is auto-skipped on SeaBIOS) → **/system read-write = Yes** (handy
for a dev box) → it writes ~2 GB → "Installation successful".

Give the installer ~10-15s to load before the first keystroke, and wait for
newt dialogs to fully render. In Yes/No dialogs the default focus is often the
*safe* choice (No/Skip) — arrow `left` to reach Yes.

### 4. Boot from disk (not back into the installer)

Set `boot=order=scsi0;ide2` via the config API, then **full power-cycle**
(stop→start). A warm reboot from the installer's menu keeps CD-first. First
boot shows a root `console:/ #` then the GUI; first boot runs dexopt (~1-3 min
at ~30% CPU — be patient, it is not stuck).

### 5. Out-of-box setup wizard (OOBE)

Drive it with the **pointer** (`pvedrive.py tap X Y`), screenshotting each
screen: START → skip Wi-Fi → CONTINUE → date/time NEXT → Google Services MORE
→ ACCEPT → screen-lock "Not now" → SKIP ANYWAY.

**If the wizard loops** (builds with GMS crash-loop back to Wi-Fi without real
Play-services connectivity), bypass it from the root console instead:

```
settings put secure user_setup_complete 1
settings put global device_provisioned 1
pm disable-user --user 0 com.google.android.setupwizard
am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

Then pick a launcher (Quickstep) → ALWAYS.

### 6. Networking + adb (the other big gotcha)

- The e1000 NIC is presented to Android as **`wifi_eth`**, NOT `eth0` (an
  Android-x86 trick so ethernet looks like Wi-Fi). `ip link` shows
  `wifi_eth`/`wlan0`; there is **no `eth0`** and **no `dhcptool`**.
- If DHCP hasn't run, assign a static LAN IP from the console:
  ```
  ip addr add 192.168.1.150/24 dev wifi_eth
  ip link set wifi_eth up
  ip route add default via 192.168.1.1 dev wifi_eth
  ```
  (Pick a free IP; check from the host with ping first.)
- Enable **adb over TCP**:
  ```
  setprop service.adb.tcp.port 5555; stop adbd; start adbd
  ```
  Verify it listens: `ss -ltn | grep 5555` → `*:5555`.
- **Android drops inbound ICMP and filters inbound TCP** — `ping` to the VM
  fails even when it's up, and adb connect gets filtered until you open it:
  ```
  iptables -I INPUT 1 -p tcp --dport 5555 -j ACCEPT
  ```
- **The fwmark return-path trap (subtle, cost hours once)**: even with adbd
  listening AND `iptables -I INPUT ... 5555 -j ACCEPT` at the top of INPUT, a
  connect from the host can still show `filtered` (silent drop, nmap
  `filtered`, not `closed`/refused). The inbound SYN *is* accepted — but
  Android's `netd` runs **fwmark policy routing** and its `ip rule` list has NO
  rule that consults the `main` table, ending in `32000: from all unreachable`.
  A manually-configured NIC's routes live in `main`, so adbd's SYN-**ACK**
  (fwmark 0) matches no rule and hits `unreachable` → dropped. Diagnose with
  `ip rule show` (look for the `32000 unreachable` catch-all and no `main`
  lookup). Fix on the VM:
  ```
  ip rule add pref 11000 lookup main
  ```
  (`main` already has the connected `<subnet>` + default route from `ip addr`/
  `ip route add` above.) TCP 5555 opens immediately after. Not persistent.
- **Where to run adb from**: connect from a machine on the VM's **L2 segment**
  (the Proxmox host or a real LAN host). A WSL2 dev box behind Windows NAT can
  reach other LAN hosts but its return path to the VM's IP is broken — adb
  connect hangs. If the host has no adb, copy the `platform-tools/adb` binary
  (and the APK) to it over SFTP and run it there (no apt install needed).

Then: `adb connect <vm-ip>:5555 && adb install app.apk`.

### 7. Persisted-state warnings

- Static IP / iptables / adb-tcp / the `ip rule ... lookup main` fix set from
  the console are **not persistent** across reboot. For permanence, see below.
- **Persisting adb-over-ethernet (what actually works on 9.0-r2):** put the
  setup commands in a script and have Android `init` invoke it on boot.
  - Two things that DON'T work on their own: the initrd does **not** run
    `/data/local/userinit.sh` (that legacy hook is not honored here), and
    `persist.adb.tcp.port 5555` does **not** make adbd listen on TCP at boot
    (`service.adb.tcp.port` stays empty — you must `setprop service.adb.tcp.port
    5555` + restart adbd in the script).
  - What works: a `oneshot` init service in **`/system/etc/init/*.rc`** (init
    auto-parses that dir) triggered `on property:sys.boot_completed=1`, running
    a `/system/bin/sh` script that (re)applies IP + `ip rule ... lookup main` +
    iptables + `service.adb.tcp.port` + restart adbd. Have the script wait for
    `wifi_eth` to appear first (boot ordering isn't guaranteed). Example rc:
    ```
    service adbnet /system/bin/sh /data/local/setup.sh
        user root
        group root
        oneshot
        disabled
        seclabel u:r:su:s0
    on property:sys.boot_completed=1
        start adbnet
    ```
  - `/system` is loop-mounted **rw** on a read-write install (`/dev/loop0` ext4),
    so you can write the `.rc` directly (`adb push`; `adb remount` may error but
    isn't needed). Build is `userdebug`/`ro.debuggable=1` and SELinux is
    **Permissive**, so `adb root` works and the service isn't SELinux-blocked.
- **Disable display sleep** in Android settings — Android-x86 can suspend on
  idle and the QEMU console goes black.
- Avoid `ctrl-alt-Fn` VT switching once the GUI is up (black-screen KMS bug —
  see `proxmox-vm-console`); prefer adb once it works.
