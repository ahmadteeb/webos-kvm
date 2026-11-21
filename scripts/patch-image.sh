#!/bin/bash
# Apply the KVM fixes to a prebuilt webOS OSE qemux86-64 image and write a qcow2.
# Usage: sudo scripts/patch-image.sh webos-image-qemux86-64.wic.vmdk webos.qcow2
# Needs: qemu-img, losetup, mount (root). Same fixes as meta-webos-kvm, applied to the finished rootfs.
set -euo pipefail
[ $# -eq 2 ] && [ "$(id -u)" -eq 0 ] || { echo "usage: sudo $0 <in.vmdk> <out.qcow2>" >&2; exit 1; }
IN=$1; OUT=$2
F="$(cd "$(dirname "$0")/.." && pwd)/meta-webos-kvm/recipes-kvm/webos-kvm-fixes/files"
TMP=$(mktemp -d -p . .webos-kvm-work.XXXXXX)   # work in the current directory, removed on exit
LOOP=
cleanup() { mountpoint -q "$TMP/root" && umount "$TMP/root"; [ -n "$LOOP" ] && losetup -d "$LOOP"; rm -rf "$TMP"; }
trap cleanup EXIT

qemu-img convert -f vmdk -O raw "$IN" "$TMP/disk.raw"
LOOP=$(losetup --find --show --partscan "$TMP/disk.raw")
mkdir "$TMP/root"
udevadm settle; for _ in 1 2 3 4 5 6 7 8 9 10; do [ -b "${LOOP}p2" ] && break; sleep 1; done   # wait for the partition node
mount "${LOOP}p2" "$TMP/root"          # partition 2 = rootfs (ext4); partition 1 = boot (FAT)
R=$TMP/root

# 1. unversioned GL names WebAppMgr dlopen()s
[ -e "$R/usr/lib/libGLESv2.so" ] || ln -s libGLESv2.so.2 "$R/usr/lib/libGLESv2.so"
[ -e "$R/usr/lib/libEGL.so" ]    || ln -s libEGL.so.1    "$R/usr/lib/libEGL.so"

# 2. atomic KMS off
E=$R/etc/surface-manager.d/eglfs-integrations/eglfs_kms_webos.env
grep -q 'QT_QPA_EGLFS_KMS_ATOMIC=1' "$E"   # fail loudly if the image layout changed
sed -i 's/QT_QPA_EGLFS_KMS_ATOMIC=1/QT_QPA_EGLFS_KMS_ATOMIC=0/' "$E"

# 3. display service (runs before the compositor on every boot)
install -m 0755 "$F/webos-kvm-display" "$R/usr/sbin/webos-kvm-display"
install -m 0644 "$F/webos-kvm-display.service" "$R/lib/systemd/system/webos-kvm-display.service"
ln -sf /usr/lib/systemd/system/webos-kvm-display.service "$R/etc/systemd/system/multi-user.target.wants/webos-kvm-display.service"

umount "$R"
qemu-img convert -p -f raw -O qcow2 "$TMP/disk.raw" "$OUT"
