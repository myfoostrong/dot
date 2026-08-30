#!/usr/bin/env python3
"""Drive a Proxmox VM console headlessly: screenshot, keys, typed text, pointer.

Env: PVE_HOST, PVE_NODE, PVE_USER (root@pam), PVE_PASS, PVE_VMID,
     PVE_W, PVE_H (guest framebuffer size, e.g. 1024 768),
     PVE_SSH_PASS (host root ssh password; defaults to PVE_PASS).

Usage:
  pvedrive.py shot <out.png>
  pvedrive.py keys <keysym> [keysym ...]     # e.g. down down ret ; ctrl-alt-f1
  pvedrive.py type "<text>"                   # types literally, no trailing Enter
  pvedrive.py line "<text>"                   # types text + Enter
  pvedrive.py move <x> <y>                     # pointer move (wakes GUI)
  pvedrive.py tap  <x> <y>                     # pointer tap

Screenshots and pointer both use SSH to the Proxmox HOST (paramiko). Pointer
uploads qmpclick.py (expected next to this file) to the host and runs it.
"""
import os, sys, json, ssl, time, urllib.parse, urllib.request

HOST = os.environ["PVE_HOST"]; NODE = os.environ.get("PVE_NODE", HOST.split(".")[0])
USER = os.environ.get("PVE_USER", "root@pam"); PASS = os.environ["PVE_PASS"]
SSH_PASS = os.environ.get("PVE_SSH_PASS", PASS)
VMID = os.environ["PVE_VMID"]; W = int(os.environ.get("PVE_W", "1024")); H = int(os.environ.get("PVE_H", "768"))
BASE = f"https://{HOST}:8006/api2/json"
CTX = ssl.create_default_context(); CTX.check_hostname = False; CTX.verify_mode = ssl.CERT_NONE


def auth():
    data = urllib.parse.urlencode({"username": USER, "password": PASS}).encode()
    d = json.load(urllib.request.urlopen(BASE + "/access/ticket", data=data, context=CTX))["data"]
    return d["ticket"], d["CSRFPreventionToken"]


def post(path, params, tkt, csrf):
    req = urllib.request.Request(BASE + path, data=urllib.parse.urlencode(params).encode(), method="POST")
    req.add_header("Cookie", "PVEAuthCookie=" + tkt); req.add_header("CSRFPreventionToken", csrf)
    return json.load(urllib.request.urlopen(req, context=CTX)).get("data")


def hmp(cmd, tkt, csrf):
    return post(f"/nodes/{NODE}/qemu/{VMID}/monitor", {"command": cmd}, tkt, csrf)


def sendkeys(keys, tkt, csrf, delay=0.35):
    for k in keys:
        hmp(f"sendkey {k}", tkt, csrf); time.sleep(delay)


SHIFTED = {'_': 'minus', '|': 'backslash', '"': 'apostrophe', ':': 'semicolon', '*': '8',
           '(': '9', ')': '0', '&': '7', '>': 'dot', '<': 'comma', '+': 'equal', '?': 'slash',
           '!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '{': 'bracket_left',
           '}': 'bracket_right', '~': 'grave_accent'}
PLAIN = {' ': 'spc', '.': 'dot', '-': 'minus', '/': 'slash', '=': 'equal', ',': 'comma',
         ';': 'semicolon', "'": 'apostrophe', '\\': 'backslash', '\n': 'ret',
         '[': 'bracket_left', ']': 'bracket_right', '`': 'grave_accent'}


def type_str(s, tkt, csrf, delay=0.12):
    for ch in s:
        if ch.isalpha() and ch.islower(): k = ch
        elif ch.isalpha(): k = 'shift-' + ch.lower()
        elif ch.isdigit(): k = ch
        elif ch in SHIFTED: k = 'shift-' + SHIFTED[ch]
        elif ch in PLAIN: k = PLAIN[ch]
        else: continue
        hmp(f"sendkey {k}", tkt, csrf); time.sleep(delay)


def ssh():
    import paramiko
    c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, username="root", password=SSH_PASS, timeout=15,
              allow_agent=False, look_for_keys=False)
    return c


def shot(out, tkt, csrf):
    hmp(f"screendump /tmp/vmshot_{VMID}.ppm", tkt, csrf); time.sleep(0.6)
    c = ssh(); c.open_sftp().get(f"/tmp/vmshot_{VMID}.ppm", out + ".ppm"); c.close()
    from PIL import Image
    Image.open(out + ".ppm").save(out); print("shot ->", out)


def pointer(cmd, x, y):
    c = ssh()
    local = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qmpclick.py")
    c.open_sftp().put(local, "/root/qmpclick.py")
    i, o, e = c.exec_command(f"python3 /root/qmpclick.py {VMID} {W} {H} {cmd} {x} {y}")
    print(o.read().decode() + e.read().decode(), end=""); c.close()


def main():
    cmd = sys.argv[1]; tkt, csrf = auth()
    if cmd == "shot": shot(sys.argv[2], tkt, csrf)
    elif cmd == "keys": sendkeys(sys.argv[2:], tkt, csrf)
    elif cmd == "type": type_str(sys.argv[2], tkt, csrf)
    elif cmd == "line": type_str(sys.argv[2] + "\n", tkt, csrf)
    elif cmd in ("move", "tap"): pointer(cmd, int(sys.argv[2]), int(sys.argv[3]))
    else: print(__doc__); sys.exit(1)


if __name__ == "__main__":
    main()
