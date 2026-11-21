#!/bin/bash
# Define the webOS VM in libvirt with the GPU render node chosen automatically.
# libvirt cannot pick the GPU itself, and on hybrid laptops its default is often the proprietary NVIDIA
# GPU, which QEMU cannot use ("egl: eglInitialize failed: EGL_NOT_INITIALIZED"). This picks the first
# render node whose kernel driver is not "nvidia" (Intel/AMD/nouveau/virtio) and writes it into the XML.
# Usage: define-vm.sh [path/to/webos.xml]     (no root needed, needs the libvirt group)
set -euo pipefail
XML=${1:-$(dirname "$0")/../libvirt/webos.xml}
NODE=
for n in /sys/class/drm/renderD*; do
    [ -e "$n" ] || continue
    [ "$(basename "$(readlink -f "$n/device/driver")")" = nvidia ] && continue
    NODE=/dev/dri/$(basename "$n"); break
done
[ -n "$NODE" ] || { echo "no usable GPU render node (need /dev/dri/renderD* with a non-nvidia driver)" >&2; exit 1; }
echo "using render node $NODE"
TMP=$(mktemp -p . .webos-kvm-define.XXXXXX); trap 'rm -f "$TMP"' EXIT
sed -E "s#rendernode='[^']*'#rendernode='$NODE'#" "$XML" > "$TMP"
# re-defining an existing VM needs its UUID, or libvirt refuses ("already exists with uuid")
NAME=$(sed -n 's#.*<name>\(.*\)</name>.*#\1#p' "$TMP" | head -n 1)
UUID=$(virsh -c qemu:///system domuuid "$NAME" 2>/dev/null || true)
[ -z "$UUID" ] || sed -i "s#<name>$NAME</name>#&\n  <uuid>$UUID</uuid>#" "$TMP"
grep -q "rendernode='$NODE'" "$TMP"   # fail if the XML has no <gl rendernode=...> to fill in
virsh -c qemu:///system define "$TMP"
