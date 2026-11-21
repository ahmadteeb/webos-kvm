# 📺 webOS on KVM (`webos-kvm`)

Run **webOS Open Source Edition (OSE)** (`qemux86-64`) seamlessly inside **QEMU/KVM** using **virt-manager** with full 3D hardware acceleration (`virgl`).

Stock webOS OSE images do not boot a working graphical interface under standard KVM virtual machines. This repository provides:
1. **[meta-webos-kvm](meta-webos-kvm/)**: A lightweight Yocto layer with the display, KMS, and OpenGL fixes required for KVM.
2. **[libvirt/webos.xml](libvirt/webos.xml)**: A ready-to-use libvirt VM definition tuned for virt-manager.
3. **Pre-built release images**: Ready-to-run `.qcow2` images published via GitHub Actions (upstream's prebuilt image plus our fixes).

---

## ⚡ Quick Navigation

- [1. Host Setup: Install KVM & virt-manager](#1-host-setup-install-kvm--virt-manager)
  - [Hardware Check](#hardware-check)
  - [Distro Packages (Arch, Ubuntu/Debian, Fedora, openSUSE)](#install-packages)
  - [User Permissions & Networking](#user-permissions--network-setup)
- [2. Quick Start: Install Pre-Built Image from Releases](#2-quick-start-install-pre-built-image-from-releases)
  - [Step 1: Download Release Files](#step-1-download-release-files)
  - [Step 2: Unpack](#step-2-unpack)
  - [Step 3: Copy Disk to Libvirt Images](#step-3-copy-disk-to-libvirt-images)
  - [Step 4: Define VM in virt-manager](#step-4-define-vm-in-virt-manager)
  - [Step 5: Launch & Control](#step-5-launch--control)
- [3. Optional: Make or Build the Image Yourself](#3-optional-make-or-build-the-image-yourself)
  - [Option A: Patch the prebuilt upstream image (minutes)](#option-a-patch-the-prebuilt-upstream-image-minutes)
  - [Option B: Build from source (hours)](#option-b-build-from-source-hours)
  - [Build Requirements](#build-requirements)
  - [Step-by-Step Build in Distrobox / Container](#step-by-step-build-in-distrobox)
- [Keyboard and mouse mapping](#keyboard-and-mouse-mapping)
- [4. Reference: Fixes & VM Settings](#4-reference-fixes--vm-settings)
- [5. Troubleshooting & FAQ](#5-troubleshooting--faq)

---

## 1. Host Setup: Install KVM & virt-manager

### Hardware Check

Ensure your CPU has hardware virtualization enabled in BIOS/UEFI and a GPU render node is available:

```bash
ls /dev/kvm /dev/dri/renderD*
```
> Both `/dev/kvm` and at least one render node (e.g., `/dev/dri/renderD128`) must exist. webOS requires 3D acceleration (`virgl`) to launch its compositor.

---

### Install Packages

Install QEMU, KVM, libvirt, virt-manager, and decompression tools for your Linux distribution:

#### 🐧 Arch Linux / Manjaro / EndeavourOS
```bash
sudo pacman -S --needed qemu-desktop libvirt virt-manager dnsmasq xz
sudo systemctl enable --now libvirtd.service
```

#### 🐧 Ubuntu / Debian / Linux Mint / Pop!_OS
```bash
sudo apt update
sudo apt install qemu-system-x86 libvirt-daemon-system libvirt-clients virt-manager dnsmasq-base xz-utils
sudo systemctl enable --now libvirtd
```

#### 🐧 Fedora / RHEL / Rocky Linux
```bash
sudo dnf install @virtualization xz
sudo systemctl enable --now libvirtd
```

#### 🐧 openSUSE (Tumbleweed / Leap)
```bash
sudo zypper install -t pattern kvm_server kvm_tools
sudo zypper install virt-manager xz
sudo systemctl enable --now libvirtd
```

---

### User Permissions & Network Setup

Run the following commands on any distribution to allow your user to manage VMs without `sudo` and enable the default NAT network:

```bash
# 1. Add your user to the libvirt and kvm groups
sudo usermod -aG libvirt,kvm "$USER"

# 2. Start and enable default NAT virtual network
sudo virsh net-autostart default
sudo virsh net-start default
```

> [!IMPORTANT]
> **Log out and log back in** (or reboot) for group changes to take effect. Verify by running `id` in your terminal — you should see `libvirt` in the group list.

---

## 2. Quick Start: Install Pre-Built Image from Releases

The fastest way to get started. No compiling needed!

### Step 1: Download Release Files

Go to the [Releases](https://github.com/ahmadteeb/webos-kvm/releases) page and download:
- `webos-kvm-<tag>.tar.bz2` (e.g. `webos-kvm-v2.28.0.tar.bz2`)

*(Alternatively, use GitHub CLI: `gh release download --repo ahmadteeb/webos-kvm`)*

---

### Step 2: Unpack

In the directory where you downloaded the files:

```bash
tar -xjf webos-kvm-*.tar.bz2
```

---

### Step 3: Copy Disk to Libvirt Images

Copy the disk image to the default libvirt storage pool path expected by `webos.xml`:

```bash
sudo cp webos-kvm-*.qcow2 /var/lib/libvirt/images/webos.qcow2
virsh -c qemu:///system pool-refresh default    # lets libvirt (and virt-manager) know about the new disk
```

---

### Step 4: Define VM in virt-manager

Define the VM with the helper script. It picks a GPU render node that works for 3D automatically (on laptops with
an NVIDIA + Intel/AMD GPU, QEMU's default is the NVIDIA one and fails with `EGL_NOT_INITIALIZED`) and runs `virsh define`:

```bash
# Download the script and the VM definition (they are not part of the release):
wget https://raw.githubusercontent.com/ahmadteeb/webos-kvm/main/scripts/define-vm.sh
wget https://raw.githubusercontent.com/ahmadteeb/webos-kvm/main/libvirt/webos.xml
bash define-vm.sh webos.xml

# Or from a clone of this repository:
scripts/define-vm.sh
```

---

### Step 5: Launch & Control

1. Open **Virtual Machine Manager (`virt-manager`)**.
2. Connect to **QEMU/KVM** (the *System* connection).
3. Select **`webos`** and click **Open / Run** (Play icon) to start the VM.
4. Double-click the VM to open the graphical console.

> [!NOTE]
> - **Every boot**: the display service configures the screen geometry and restarts the compositor, so the GUI takes about a minute to appear. If the screen stays black, press the **Super** key (it opens the home screen).
> - **Serial Terminal Login**: Run `virsh -c qemu:///system console webos` (`root`, no password). Press `Ctrl + ]` to exit.
> - **Keys and mouse**: see [Keyboard and mouse mapping](#keyboard-and-mouse-mapping).
> - **Graceful Shutdown**: Always shut down cleanly from inside the VM with `poweroff` or via virt-manager's Shutdown button.

---

## 3. Optional: Make or Build the Image Yourself

### Option A: Patch the prebuilt upstream image (minutes)

This is what the release workflow does. No Yocto build: it takes the prebuilt
`webos-ose-*-qemux86-64.tar.bz2` from [build-webos releases](https://github.com/webosose/build-webos/releases)
(not the `-devel` one), applies the same fixes with [scripts/patch-image.sh](scripts/patch-image.sh) and converts it to qcow2.
Needs ~10 GB free, `qemu-img` (package `qemu-img` / `qemu-utils`) and root (it loop-mounts the image).

```bash
# download the newest qemux86-64 asset (example: v2.28.0), or grab it in a browser
curl -LO https://github.com/webosose/build-webos/releases/download/v2.28.0/webos-ose-2-28-0-qemux86-64.tar.bz2

tar -xjf webos-ose-*-qemux86-64.tar.bz2       # gives webos-image-qemux86-64.wic.vmdk
sudo scripts/patch-image.sh webos-image-qemux86-64.wic.vmdk webos.qcow2
```

Then continue at [Step 3: Copy Disk to Libvirt Images](#step-3-copy-disk-to-libvirt-images).

### Option B: Build from source (hours)

If you want a custom webOS OSE version, different resolution, or want to modify recipes, you can build from [webosose/build-webos](https://github.com/webosose/build-webos) with our [meta-webos-kvm](meta-webos-kvm/) layer.

### Build Requirements
- **Disk Space**: ~150 GB free disk space
- **Memory**: 16 GB+ RAM recommended
- **Time**: Several hours depending on CPU cores
- **Tool**: We strongly recommend using **Distrobox** (with Podman or Docker) to keep build dependencies isolated from your host OS.

---

### Step-by-Step Build in Distrobox

#### 1. Prepare Host Container Environment
```bash
# Arch: sudo pacman -S distrobox podman
# Ubuntu/Debian: sudo apt install distrobox podman
# Fedora: sudo dnf install distrobox podman

# Create and enter an Ubuntu 22.04 build container
distrobox create --yes --name webos-build --image ubuntu:22.04
distrobox enter webos-build
```

#### 2. Inside Container: Setup Dependencies & Source Code
```bash
# Set your target version tag
TAG="v2.28.0"

# Install base tools & UTF-8 locale
sudo apt-get update
sudo apt-get install -y git locales qemu-utils
sudo locale-gen en_US.UTF-8
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Clone upstream build-webos
git clone --branch "$TAG" https://github.com/webosose/build-webos.git build-webos
cd build-webos

# Run official prerequisites script
sudo scripts/prerequisites.sh
```

#### 3. Integrate `meta-webos-kvm` Layer
```bash
# Copy meta-webos-kvm into build-webos
cp -r /path/to/webos-kvm/meta-webos-kvm build-webos/

# Initialize MCF build configuration for qemux86-64 (0 = use all CPU cores)
./mcf -p 0 -b 0 qemux86-64

# Source Yocto environment (puts you in build-webos/BUILD)
source oe-init-build-env

# Add meta-webos-kvm to your layer configuration
bitbake-layers add-layer build-webos/meta-webos-kvm

# Screen resolution is detected at boot from the virtual display (nothing to configure).
# To force a fixed size instead, add to conf/local.conf:
#   WEBOS_KVM_WIDTH = "1920"
#   WEBOS_KVM_HEIGHT = "1080"
```

#### 4. Run the Build
```bash
# Start BitBake compilation (takes several hours)
bitbake webos-image
```
*(If interrupted, re-enter with `distrobox enter webos-build`, `cd build-webos && source oe-init-build-env`, and run `bitbake webos-image` again to resume).*

#### 5. Convert Image to QCOW2
```bash
# Convert generated VMDK to qcow2
qemu-img convert -p -f vmdk -O qcow2 \
  "$(ls -t deploy/images/qemux86-64/webos-image-qemux86-64-*.wic.vmdk | head -n 1)" \
  webos.qcow2

exit
```

Now take `webos.qcow2` (in the current folder, `build-webos/BUILD`), copy it to `/var/lib/libvirt/images/webos.qcow2`, and follow [Step 4 of Quick Start](#step-4-define-vm-in-virt-manager).

---

### Keyboard and mouse mapping

The image's key map (`/usr/share/webos-keymap/webos-keymap.qmap`) is a normal PC layout plus remote-control keys. Only one key is handled by the compositor itself; every other key is passed to the app that has focus, so what it does depends on the app.

| Input | Action in webOS |
|---|---|
| **Super / Windows / Meta** (left) | Home: opens or closes the home screen (the only key the compositor handles; confirmed in the VM) |
| **Mouse click** | Tap (the USB tablet is an absolute pointer) |
| **Arrow keys**, **Enter** | Move focus and select inside webOS apps (tested in Settings). The home-screen dock does not react to keys: use the mouse there |

Read from the key map file in the image; I only pressed Super in the running VM.

## 4. Reference: Fixes & VM Settings

### What `meta-webos-kvm` Bakes In

| Fix | Component | Why It's Needed |
|---|---|---|
| **Unversioned OpenGL Symlinks** | `webos-image.bbappend` | WebAppMgr & Chromium dlopen `libGLESv2.so` and `libEGL.so` without version suffix. |
| **Atomic KMS Disabled** | `eglfs_kms_webos.env` | Sets `QT_QPA_EGLFS_KMS_ATOMIC=0` because virtio-gpu driver rejects atomic commits (`-22`). |
| **Custom Display Config** | `webos-kvm-display.service` | Sends Luna config setting geometry (`WxH+0+0r0s1`) and format (`xrgb8888`) so surface-manager doesn't crash on ARGB pageflips. |
| **Compositor Auto-Restart** | `webos-kvm-display` | Applies the display config and restarts `surface-manager-daemon.service` on every boot (the setting does not survive a reboot). |

---

### Crucial VM Settings in `libvirt/webos.xml`

- **Disk Bus (`IDE`)**: Must be IDE or SATA (`hda`), not VirtIO (`vda`), because the stock initramfs waits specifically for `/dev/sda1`.
- **Firmware (`BIOS`)**: Uses SeaBIOS (`machine='pc'`). The image boots using SYSLINUX, not UEFI.
- **Video (`virtio` + 3D `virgl`)**: Kernel lacks VMware/Intel drivers in the image; software GL crashes the web runtime.
- **Graphics (`SPICE` + OpenGL)**: virgl renders on the host GPU and virt-manager's SPICE viewer shows it directly, with no CPU compression. (`egl-headless` + VNC also works but its encoder maxes one CPU core, so the UI and video lag.) The GPU render node is chosen by `scripts/define-vm.sh`.
- **Audio (`ac97`)**: the image kernel has the AC97 driver, not HDA; the guest already has a sound card and PulseAudio. The default host backend is `none` (silent), because the VM runs as the `libvirt-qemu` user and cannot reach your desktop audio. To enable sound, give the VM a loopback-only PulseAudio TCP socket (works with PipeWire's `pipewire-pulse` too, no sudo):
  1. Open the socket (now, and on every login via a config drop-in):
     ```bash
     pactl load-module module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-ip-acl=127.0.0.1
     mkdir -p ~/.config/pipewire/pipewire-pulse.conf.d
     cat > ~/.config/pipewire/pipewire-pulse.conf.d/webos-kvm-tcp.conf <<'EOF'
     pulse.cmd = [
         { cmd = "load-module" args = "module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-ip-acl=127.0.0.1" flags = [ ] }
     ]
     EOF
     ```
  2. In `libvirt/webos.xml` replace `<audio id='1' type='none'/>` with `<audio id='1' type='pulseaudio' serverName='tcp:127.0.0.1:4713'/>`, then `virsh -c qemu:///system define libvirt/webos.xml` and restart the VM.
  Any local program can then play sound through that socket; it is not reachable from the network.
- **Input (`USB Tablet`)**: Absolute pointer positioning so no mouse grab or trapping is required.

---

## 5. Troubleshooting & FAQ

| Symptom / Error | Cause | Solution |
|---|---|---|
| `Expecting device /dev/sda1` / Emergency mode | Disk set to VirtIO bus | Ensure disk bus is **IDE** in VM settings (`<target dev='hda' bus='ide'/>`). |
| Black screen / Compositor crash in `libEGL` | Software rendering or missing 3D accel | Check `ls /dev/dri/renderD*`. Ensure 3D acceleration is enabled in VM settings. |
| `virsh define`: Permission denied | User not in `libvirt` group | Run `sudo usermod -aG libvirt,kvm "$USER"` and **re-login**. |
| `virsh start`: failed to open render node | Multiple GPUs / wrong node | Edit graphics entry in XML to pin your GPU: `<gl rendernode='/dev/dri/renderD128'/>`. |
| No mouse cursor visible | webOS draws no pointer in the VM; the SPICE viewer only shows a cursor the guest provides | Expected: the mouse still works, clicks are taps. Tried without success: hardware cursor and a relative mouse. The VNC console draws a local pointer but is laggy (see the VM settings above). |
| VM not showing in virt-manager | Connected to user session | Ensure virt-manager connects to `QEMU/KVM` (System: `qemu:///system`), not Session. |

---

## 📄 License

The configuration and fixes in this repository are released under the **Apache-2.0 License**. webOS Open Source Edition is copyright LG Electronics and respective contributors.
