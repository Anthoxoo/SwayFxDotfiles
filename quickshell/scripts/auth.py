#!/usr/bin/env python3
import sys
import os
import getpass
import subprocess

def verify_password(pwd):
    user = getpass.getuser()
    for bin_path in ("/usr/sbin/unix_chkpwd", "/sbin/unix_chkpwd"):
        if os.path.exists(bin_path):
            try:
                res = subprocess.run(
                    [bin_path, user, "nullok"],
                    input=pwd.encode("utf-8") + b"\x00",
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5
                )
                return res.returncode == 0
            except Exception:
                pass
    return False

if __name__ == "__main__":
    pwd = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read().rstrip("\r\n")
    if verify_password(pwd):
        print("OK", flush=True)
        sys.exit(0)
    else:
        print("FAIL", flush=True)
        sys.exit(1)
