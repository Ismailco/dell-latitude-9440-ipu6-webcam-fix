# New Arch Install

Use this path on a fresh Arch Linux install for a Dell Latitude 9440 or 9440
2-in-1 with the Intel IPU6 / `ov02c10` webcam.

## One Command

```bash
./scripts/bootstrap-arch.sh
```

The bootstrap script installs official Arch packages, installs the active
kernel headers, installs the IPU6 DKMS driver package from AUR, then runs the
existing bridge installer.

If the machine is not detected as a Latitude 9440:

```bash
./scripts/bootstrap-arch.sh --force
```

## What Gets Installed

Official Arch packages:

```text
base-devel
git
dkms
linux-firmware-intel
<active-kernel>-headers
libcamera
libcamera-tools
pipewire-libcamera
gst-plugin-libcamera
gstreamer
gst-plugins-base
gst-plugins-good
v4l2loopback-dkms
v4l2loopback-utils
v4l-utils
wireplumber
pipewire
psmisc
```

Default AUR package:

```text
intel-ipu6-dkms-git
```

Optional AUR packages, only if you pass `--with-ipu6-hal`:

```text
intel-ipu6-camera-bin
intel-ipu6-camera-hal-git
icamerasrc-git
```

Those optional packages are for Intel's HAL/icamerasrc stack. This repo's
default bridge uses Arch's `libcamera` + `gst-plugin-libcamera` path, so the
optional HAL stack is not required for the tested setup.

## AUR Handling

The script auto-detects `paru` or `yay` if installed:

```bash
./scripts/bootstrap-arch.sh --aur-helper paru
./scripts/bootstrap-arch.sh --aur-helper yay
```

If no AUR helper is found, it clones the AUR package into:

```text
${XDG_CACHE_HOME:-~/.cache}/dell-9440-ipu6-aur
```

Then it asks you to review the `PKGBUILD` before running `makepkg -si`.

To install only official packages and skip the AUR driver:

```bash
./scripts/bootstrap-arch.sh --no-aur
```

## After Bootstrap

If `pacman` upgraded the kernel or DKMS built new modules, reboot before
testing:

```bash
reboot
```

Then run:

```bash
./scripts/doctor.sh
./scripts/test-camera.sh
```

In apps and websites, choose `VirtualCam`.

## Kernel Updates

After future kernel updates, DKMS should rebuild the IPU6 and v4l2loopback
modules automatically. If the camera disappears after an update, reboot first,
then run:

```bash
dkms status
./scripts/doctor.sh
```

If headers are missing for the running kernel, install the matching package.
For Arch's stock kernel this is usually:

```bash
sudo pacman -S linux-headers
```

For `linux-lts`, use:

```bash
sudo pacman -S linux-lts-headers
```

## Sources

- Official Arch package API: `https://archlinux.org/packages/search/json/`
- Official AUR RPC API: `https://aur.archlinux.org/rpc/`
