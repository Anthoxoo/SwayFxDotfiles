#!/usr/bin/env python3
"""Wallpaper thumbnails for the wallpaper picker (modules/ThemeMenu.qml).

    wall-thumbs.py list <dir>   the number of images of <dir>, then one "<image>\\t<thumbnail>"
                                line per image, sorted; missing thumbnails are made on the way
                                (lines are flushed one by one, so the picker fills in as they come)
    wall-thumbs.py paths <dir>  the images of <dir> and of its subdirectories, one path per line
                                (no thumbnails: the wallpaper list of core/Wallpapers.qml)
    wall-thumbs.py warm <dir>...
                                makes every missing thumbnail under the <dir>s (run at startup),
                                then removes the thumbnails of images that are in none of them

A <dir> that is a link is followed first (themes/<id>/backgrounds -> ../../walls/<id>), so the
picker, `qs ipc call wallpaper` and the saved state all name a file ~/.config/walls/<id>/<file>
(the links above it, e.g. a ~/.config/walls that points into another folder, are kept as is).
Thumbnails live in ~/.cache/quickshell/wallthumbs, named after the image's path, size and mtime
(an edited image gets a new one). Made with ImageMagick, else Pillow; with neither, the
"thumbnail" is the image itself (the picker then decodes full-size images: slower).
"""
import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

EXTS = {".jpg", ".jpeg", ".png", ".webp"}
SIZE = (480, 300)  # covers a picker cell twice over
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "quickshell" / "wallthumbs"
MAGICK = shutil.which("magick") or shutil.which("convert")


def follow(d):
    """d with its own links followed, but not those of its parents"""
    d = os.path.abspath(os.path.expanduser(d))
    for _ in range(40):
        if not os.path.islink(d):
            break
        d = os.path.normpath(os.path.join(os.path.dirname(d), os.readlink(d)))
    return Path(d)


def images(root):
    root = follow(root)
    if not root.is_dir():
        return []
    return sorted(p for p in root.iterdir() if p.suffix.lower() in EXTS and p.is_file())


def images_under(roots):
    for root in roots:
        for d, _, _ in os.walk(root, followlinks=True):
            yield from images(d)


def thumb_path(img):
    st = img.stat()
    key = f"{img.resolve()}|{st.st_size}|{st.st_mtime_ns}".encode()
    return CACHE / (hashlib.sha1(key).hexdigest() + ".jpg")


def make(img, dst):
    tmp = dst.with_suffix(f".{os.getpid()}.tmp.jpg")
    w, h = SIZE
    try:
        if MAGICK:
            subprocess.run([MAGICK, f"{img}[0]", "-auto-orient", "-thumbnail", f"{w}x{h}^",
                            "-background", "black", "-alpha", "remove", "-quality", "85", str(tmp)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
        else:
            from PIL import Image, ImageOps
            with Image.open(img) as im:
                im = ImageOps.exif_transpose(im).convert("RGB")
                scale = max(w / im.width, h / im.height)
                if scale < 1:
                    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
                im.save(tmp, "JPEG", quality=85)
        tmp.replace(dst)  # atomic: the picker never sees half a file
        return True
    except Exception:
        tmp.unlink(missing_ok=True)
        return False


def thumb(img):
    dst = thumb_path(img)
    if dst.exists() or make(img, dst):
        return dst
    return img  # no tool, or an image the tools can't read: show the image itself


def main():
    mode, roots = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 2 else (None, [])
    if mode not in ("list", "paths", "warm") or (mode != "warm" and len(roots) != 1):
        sys.exit(__doc__)
    if mode == "paths":
        root = follow(roots[0])
        subdirs = sorted(d for d in root.iterdir() if d.is_dir()) if root.is_dir() else []
        for d in [root, *subdirs]:
            for img in images(d):
                print(img)
        return
    CACHE.mkdir(parents=True, exist_ok=True)
    if mode == "list":
        imgs = images(roots[0])
        print(len(imgs), flush=True)
        for img in imgs:
            print(f"{img}\t{thumb(img)}", flush=True)
        return
    keep = {thumb(img).name for img in images_under(roots)}
    for old in CACHE.iterdir():
        if old.name not in keep and not old.name.endswith(".tmp.jpg"):
            old.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
