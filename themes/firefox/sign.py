#!/usr/bin/env python3
"""Gets the Theme Sync extension signed by Mozilla (unlisted: never published on AMO).

A signed extension loads in every Firefox-based browser (Firefox release, ESR, Zen...), so
no browser needs xpinstall.signatures.required=false.

    ~/.config/themes/firefox/sign.py

Needs AMO API credentials (https://addons.mozilla.org/developers/addon/api/key/): the script
asks for them (input hidden), or reads AMO_JWT_ISSUER / AMO_JWT_SECRET. They are never stored.
Each signing needs a new "version" in extension/manifest.json. The signed file is written
to firefox/theme-sync.xpi, which firefox-setup.sh installs.
"""
import base64
import getpass
import hashlib
import hmac
import io
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

API = "https://addons.mozilla.org/api/v5"
HERE = Path(__file__).resolve().parent
EXT = HERE / "extension"
OUT = HERE / "theme-sync.xpi"
FILES = ["manifest.json", "background.js", "newtab.html", "newtab.js"]


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


class Amo:
    def __init__(self, issuer, secret):
        self.issuer, self.secret = issuer, secret.encode()

    def token(self):
        now = int(time.time())
        head = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
        body = b64(json.dumps({"iss": self.issuer, "jti": secrets.token_hex(16),
                               "iat": now, "exp": now + 60}).encode())
        sig = b64(hmac.new(self.secret, f"{head}.{body}".encode(), hashlib.sha256).digest())
        return f"{head}.{body}.{sig}"

    def request(self, method, url, data=None, ctype=None, raw=False):
        req = urllib.request.Request(url if url.startswith("http") else API + url,
                                     data=data, method=method)
        req.add_header("Authorization", "JWT " + self.token())
        if ctype:
            req.add_header("Content-Type", ctype)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                payload = r.read()
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode(errors="replace")
        return 200, payload if raw else json.loads(payload or b"{}")

    def post_json(self, url, obj):
        return self.request("POST", url, json.dumps(obj).encode(), "application/json")


def build_xpi():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for name in FILES:
            z.write(EXT / name, name)
    return buf.getvalue()


def multipart(fields, filename, content):
    boundary = secrets.token_hex(16)
    out = io.BytesIO()
    for key, value in fields.items():
        out.write(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n'
                  f"{value}\r\n".encode())
    out.write(f'--{boundary}\r\nContent-Disposition: form-data; name="upload"; '
              f'filename="{filename}"\r\nContent-Type: application/x-xpinstall\r\n\r\n'.encode())
    out.write(content + f"\r\n--{boundary}--\r\n".encode())
    return out.getvalue(), f"multipart/form-data; boundary={boundary}"


def fail(msg, detail=None):
    print(f"error: {msg}", file=sys.stderr)
    if detail:
        print(detail if isinstance(detail, str) else json.dumps(detail, indent=2), file=sys.stderr)
    sys.exit(1)


def poll(what, fn, done, timeout=900):
    start = time.time()
    while True:
        result = fn()
        if done(result):
            return result
        if time.time() - start > timeout:
            fail(f"{what}: still waiting after {timeout // 60} min, run the script again later")
        print(f"  {what}...", flush=True)
        time.sleep(10)


def main():
    manifest = json.loads((EXT / "manifest.json").read_text())
    guid = manifest["browser_specific_settings"]["gecko"]["id"]
    version = manifest["version"]
    print(f"Theme Sync {version} ({guid})")

    issuer = os.environ.get("AMO_JWT_ISSUER") or input("AMO API key (JWT issuer, user:...): ").strip()
    secret = os.environ.get("AMO_JWT_SECRET") or getpass.getpass("AMO API secret (hidden): ").strip()
    if not issuer or not secret:
        fail("API key and secret are both needed")
    if not issuer.startswith("user:"):  # AMO shows it as user:12345678:123
        issuer = "user:" + issuer
    amo = Amo(issuer, secret)

    print("Uploading...")
    body, ctype = multipart({"channel": "unlisted"}, "theme-sync.xpi", build_xpi())
    code, up = amo.request("POST", "/addons/upload/", body, ctype)
    if code != 200:
        fail(f"upload refused (HTTP {code})", up)

    up = poll("validation", lambda: amo.request("GET", f"/addons/upload/{up['uuid']}/")[1],
              lambda u: isinstance(u, dict) and u.get("processed"))
    if not up.get("valid"):
        msgs = [m.get("message") for m in up.get("validation", {}).get("messages", [])
                if m.get("type") == "error"]
        fail("the extension did not pass validation", "\n".join(f"  - {m}" for m in msgs) or up)

    print("Submitting the version...")
    code, ver = amo.post_json(f"/addons/addon/{guid}/versions/", {"upload": up["uuid"]})
    if code == 404:  # first signing: the add-on doesn't exist yet on AMO
        code, addon = amo.post_json("/addons/addon/", {"version": {"upload": up["uuid"]}})
        ver = addon.get("version") if code in (200, 201) and isinstance(addon, dict) else addon
    if code not in (200, 201):
        if "already exists" in str(ver):
            fail(f"version {version} was already submitted: bump \"version\" in manifest.json", ver)
        fail(f"submission refused (HTTP {code})", ver)

    def file_of():
        c, v = amo.request("GET", f"/addons/addon/{guid}/versions/{ver['id']}/")
        return v.get("file") if c == 200 and isinstance(v, dict) else None

    f = poll("signing", file_of, lambda f: f and f.get("status") == "public" and f.get("url"))
    code, xpi = amo.request("GET", f["url"], raw=True)
    if code != 200 or not xpi.startswith(b"PK"):
        fail(f"download of the signed file failed (HTTP {code})")
    with zipfile.ZipFile(io.BytesIO(xpi)) as z:
        if not any(n.startswith("META-INF/") for n in z.namelist()):
            fail("the downloaded file has no signature (META-INF/ missing)")
    tmp = OUT.with_suffix(".tmp")
    tmp.write_bytes(xpi)
    tmp.replace(OUT)
    print(f"Signed: {OUT}\nNow run ~/.config/themes/firefox-setup.sh")


if __name__ == "__main__":
    main()
