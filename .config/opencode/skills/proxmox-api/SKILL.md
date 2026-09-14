---
name: proxmox-api
description: >
  Interact with a Proxmox VE server over its REST API — authenticate (ticket +
  CSRF), list/create/start/stop VMs, download ISOs to storage, run QEMU monitor
  commands, and poll tasks. Use whenever the user asks to connect to, inspect,
  or drive a Proxmox host or its VMs/containers over the network. Pairs with
  the `proxmox-vm-console` skill for headless screen/keyboard/pointer control.
---

## Proxmox VE REST API

Base URL is `https://<host>:8006/api2/json`. The web UI cert is self-signed, so
every call needs `curl -k` (or `verify=False`). Read-only `GET`s need only the
auth cookie; every mutating `POST`/`PUT`/`DELETE` **also** needs the
`CSRFPreventionToken` header. Tickets expire after ~2h — just re-auth.

### Connection details / credentials

Never hardcode credentials in committed files. Read them from the environment:

```
export PVE_HOST=box01.home PVE_NODE=box01 PVE_USER=root@pam PVE_PASS='...'
```

Known hosts and credentials are not stored in this skill. If these variables
are not already available from the environment or project context, ask the
user; never guess or persist credentials.

### Authenticate

```bash
RESP=$(curl -sk --data-urlencode "username=$PVE_USER" \
  --data-urlencode "password=$PVE_PASS" \
  "https://$PVE_HOST:8006/api2/json/access/ticket")
TICKET=$(echo "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['ticket'])")
CSRF=$(echo   "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['CSRFPreventionToken'])")
```

Then: `-H "Cookie: PVEAuthCookie=$TICKET"` on every call, plus
`-H "CSRFPreventionToken: $CSRF"` on writes.

### Endpoints used most

| Purpose | Method | Path |
|---|---|---|
| Nodes / version | GET | `/nodes`, `/version` |
| Next free VMID | GET | `/cluster/nextid` |
| List VMs | GET | `/nodes/{node}/qemu` |
| VM config | GET/POST | `/nodes/{node}/qemu/{vmid}/config` |
| Create VM | POST | `/nodes/{node}/qemu` |
| Lifecycle | POST | `/nodes/{node}/qemu/{vmid}/status/{start,stop,reset,shutdown}` |
| Current status | GET | `/nodes/{node}/qemu/{vmid}/status/current` (`qmpstatus`, `cpu`, `mem`, `uptime`) |
| Storage list | GET | `/nodes/{node}/storage` (check `content` includes `iso`) |
| Storage content | GET | `/nodes/{node}/storage/{storage}/content?content=iso` |
| **Download ISO by URL** | POST | `/nodes/{node}/storage/{storage}/download-url` |
| QEMU monitor (HMP) | POST | `/nodes/{node}/qemu/{vmid}/monitor` (`command=...`) |
| Task status / log | GET | `/nodes/{node}/tasks/{upid}/status` and `/log` (URL-encode the UPID) |

### Download an ISO straight to a node (no local download)

```bash
curl -sk -H "Cookie: PVEAuthCookie=$TICKET" -H "CSRFPreventionToken: $CSRF" \
  --data-urlencode "content=iso" \
  --data-urlencode "filename=android-x86_64-9.0-r2.iso" \
  --data-urlencode "url=https://downloads.sourceforge.net/project/android-x86/Release 9.0/android-x86_64-9.0-r2.iso" \
  "https://$PVE_HOST:8006/api2/json/nodes/$PVE_NODE/storage/local/download-url"
```

Returns a `UPID:...` task id. Poll `/tasks/{upid-urlencoded}/status` until
`status=stopped` and check `exitstatus=OK`. Proxmox follows redirects (e.g.
SourceForge mirror selection) with wget, so a redirecting URL is fine.

### Creating a VM (form-encoded params on POST /qemu)

Pass each option as its own `--data-urlencode`. Disk `scsi0=local-lvm:16`
(size in GiB). CD-ROM `ide2=local:iso/<file>,media=cdrom`. NIC
`net0=e1000,bridge=vmbr0`. `boot=order=ide2;scsi0` boots CD first.
`vga=std`. See the `android-x86-proxmox` skill for a full known-good config.

### Gotchas learned the hard way

- **CSRF token is mandatory on POST** — GETs succeed without it, writes 401.
- **`download-url` + checksum**: passing `checksum-algorithm` *requires* a
  `checksum` value too, else "Parameter verification failed". Omit both to
  skip verification.
- **HMP monitor is not QMP.** The `/monitor` endpoint runs *human* monitor
  commands (`sendkey`, `screendump`, `system_wakeup`, `info ...`). It does
  **not** accept QMP verbs like `input-send-event`. For QMP (pointer/tablet
  events) talk to the host's `/var/run/qemu-server/{vmid}.qmp` socket over SSH
  — see the `proxmox-vm-console` skill.
- **Ejecting a CD at runtime** via `eject ide2` fails ("Device 'ide2' not
  found") — the QEMU drive id isn't the Proxmox name. Instead change
  `boot=order=scsi0;ide2` via the config endpoint and **full power-cycle**
  (stop then start); a *warm* reboot keeps the boot order QEMU loaded at start.
- **Self-signed TLS**: always `-k`. The node's SSL fingerprint is in `/nodes`.
- **Task UPIDs must be URL-encoded** before use in the tasks path.

### Helper

`scripts/pve.py` (env-configured) wraps auth + GET/POST + download + monitor +
lifecycle + task polling. `python3 scripts/pve.py status <vmid>` etc.
