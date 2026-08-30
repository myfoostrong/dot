#!/usr/bin/env python3
"""Send absolute pointer events to a QEMU VM via its QMP socket.

Runs ON THE PROXMOX HOST (needs local access to the qmp unix socket).
Requires a USB tablet in the guest (Proxmox default unless `tablet: 0`).

Usage:
  qmpclick.py <vmid> <W> <H> move <x> <y>
  qmpclick.py <vmid> <W> <H> tap  <x> <y>

x,y are pixel coords on a WxH framebuffer; scaled to QEMU's 0..32767 abs range.
"""
import socket, json, sys, time

ABS_MAX = 32767


def main():
    vmid, W, H, cmd = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    x, y = int(sys.argv[5]), int(sys.argv[6])
    sock = f"/var/run/qemu-server/{vmid}.qmp"
    s = socket.socket(socket.AF_UNIX); s.connect(sock)
    f = s.makefile("rw")
    f.readline()  # QMP greeting
    f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); f.flush()
    while '"return"' not in f.readline():
        pass

    def ev(events):
        f.write(json.dumps({"execute": "input-send-event",
                            "arguments": {"events": events}}) + "\n"); f.flush()
        while True:
            line = f.readline()
            if '"return"' in line:
                break
            if '"error"' in line:
                print("ERR", line.strip()); break

    absxy = [{"type": "abs", "data": {"axis": "x", "value": round(x / W * ABS_MAX)}},
             {"type": "abs", "data": {"axis": "y", "value": round(y / H * ABS_MAX)}}]
    ev(absxy)
    if cmd == "tap":
        time.sleep(0.05)
        ev([{"type": "btn", "data": {"down": True, "button": "left"}}])
        time.sleep(0.08)
        ev([{"type": "btn", "data": {"down": False, "button": "left"}}])
    print("ok", cmd, x, y)
    f.close(); s.close()


if __name__ == "__main__":
    main()
