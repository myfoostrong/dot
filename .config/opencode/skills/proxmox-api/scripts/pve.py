#!/usr/bin/env python3
"""Minimal Proxmox VE REST API helper (stdlib only).

Config via env: PVE_HOST, PVE_NODE, PVE_USER (default root@pam), PVE_PASS.
Auth ticket is cached to a temp file and refreshed on 401 / expiry.

Usage:
  pve.py get   <api-path>                 # e.g. get /nodes
  pve.py post  <api-path> k=v k=v ...     # form-encoded POST (CSRF added)
  pve.py status <vmid>                    # qmpstatus/cpu/mem/uptime
  pve.py start|stop|reset|shutdown <vmid>
  pve.py monitor <vmid> "<hmp command>"   # e.g. monitor 103 "info status"
  pve.py download <storage> <filename> <url>   # download-url, waits for task
  pve.py nextid
"""
import os, sys, json, ssl, time, tempfile, urllib.parse, urllib.request

HOST = os.environ["PVE_HOST"]
NODE = os.environ.get("PVE_NODE", HOST.split(".")[0])
USER = os.environ.get("PVE_USER", "root@pam")
PASS = os.environ["PVE_PASS"]
BASE = f"https://{HOST}:8006/api2/json"
CTX = ssl.create_default_context(); CTX.check_hostname = False; CTX.verify_mode = ssl.CERT_NONE
_CACHE = os.path.join(tempfile.gettempdir(), f"pve_ticket_{HOST}.json")


def auth():
    data = urllib.parse.urlencode({"username": USER, "password": PASS}).encode()
    d = json.load(urllib.request.urlopen(BASE + "/access/ticket", data=data, context=CTX))["data"]
    tok = {"ticket": d["ticket"], "csrf": d["CSRFPreventionToken"], "t": time.time()}
    json.dump(tok, open(_CACHE, "w"))
    return tok


def tok():
    try:
        t = json.load(open(_CACHE))
        if time.time() - t["t"] < 6000:  # ~100 min, well under the 2h expiry
            return t
    except Exception:
        pass
    return auth()


def call(method, path, params=None):
    t = tok()
    url = BASE + path
    data = urllib.parse.urlencode(params).encode() if params else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Cookie", "PVEAuthCookie=" + t["ticket"])
    if method != "GET":
        req.add_header("CSRFPreventionToken", t["csrf"])
    try:
        return json.load(urllib.request.urlopen(req, context=CTX)).get("data")
    except urllib.error.HTTPError as e:
        if e.code == 401:  # ticket died — refresh once
            auth()
            return call(method, path, params)
        raise


def wait_task(upid, timeout=1800):
    enc = urllib.parse.quote(upid, safe="")
    end = time.time() + timeout
    while time.time() < end:
        s = call("GET", f"/nodes/{NODE}/tasks/{enc}/status")
        if s.get("status") == "stopped":
            return s.get("exitstatus")
        time.sleep(3)
    return "TIMEOUT"


def main():
    cmd = sys.argv[1]
    if cmd == "get":
        print(json.dumps(call("GET", sys.argv[2]), indent=2))
    elif cmd == "post":
        params = dict(kv.split("=", 1) for kv in sys.argv[3:])
        print(json.dumps(call("POST", sys.argv[2], params), indent=2))
    elif cmd == "nextid":
        print(call("GET", "/cluster/nextid"))
    elif cmd in ("start", "stop", "reset", "shutdown"):
        print(call("POST", f"/nodes/{NODE}/qemu/{sys.argv[2]}/status/{cmd}"))
    elif cmd == "status":
        d = call("GET", f"/nodes/{NODE}/qemu/{sys.argv[2]}/status/current")
        print(f"qmpstatus={d.get('qmpstatus')} cpu={d.get('cpu',0)*100:.1f}% "
              f"mem={d.get('mem',0)/1048576:.0f}MiB uptime={d.get('uptime')}s")
    elif cmd == "monitor":
        print(call("POST", f"/nodes/{NODE}/qemu/{sys.argv[2]}/monitor",
                   {"command": sys.argv[3]}))
    elif cmd == "download":
        storage, filename, url = sys.argv[2], sys.argv[3], sys.argv[4]
        upid = call("POST", f"/nodes/{NODE}/storage/{storage}/download-url",
                    {"content": "iso", "filename": filename, "url": url})
        print("task:", upid)
        print("exit:", wait_task(upid))
    else:
        print(__doc__); sys.exit(1)


if __name__ == "__main__":
    main()
