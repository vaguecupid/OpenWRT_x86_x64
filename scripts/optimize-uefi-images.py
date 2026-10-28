#!/usr/bin/env python3
"""Apply narrow image speed optimizations from the OpenWrt source root."""
from pathlib import Path

def replace_checked(text, old, new, label):
    if new in text:
        return text
    if text.count(old) != 1:
        raise SystemExit(f"Source changed: {label}; review this optimization before building")
    return text.replace(old, new, 1)

def optimize(root):
    edits = [
        ("target/linux/x86/image/Makefile", "    IMAGES-y := rootfs.img.gz", "    IMAGES-y := # UEFI-only: no standalone rootfs.img.gz", "compressed standalone rootfs"),
        ("target/linux/x86/image/Makefile", "    IMAGES-y := rootfs.img\n", "    IMAGES-y := # UEFI-only: no standalone rootfs.img\n", "standalone rootfs"),
        ("include/image.mk", "LZMA_XZ_OPTIONS := -Xpreset 9 -Xe -Xlc 0 -Xlp 2 -Xpb 2", "LZMA_XZ_OPTIONS := -Xpreset 6 -Xlc 0 -Xlp 2 -Xpb 2", "SquashFS XZ compression effort"),
        ("include/image.mk", "-comp $(SQUASHFSCOMP) $(SQUASHFSOPT)", "-processors $(shell nproc) -comp $(SQUASHFSCOMP) $(SQUASHFSOPT)", "SquashFS CPU count"),
        ("include/image-commands.mk", "$(STAGING_DIR_HOST)/bin/gzip -f -9n -c $@ $(1) > $@.new", "$(shell command -v pigz) -p $(shell nproc) -f -6n -c $@ $(1) > $@.new", "final image parallel gzip"),
    ]
    pending = {}
    for name, old, new, label in edits:
        path = root / name
        text = pending.get(path, path.read_text())
        pending[path] = replace_checked(text, old, new, label)
    # Write only once every expected rule has been verified.
    for path, text in pending.items():
        path.write_text(text)

if __name__ == "__main__":
    optimize(Path.cwd())
