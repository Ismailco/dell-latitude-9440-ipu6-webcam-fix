# Dell Latitude 9440 IPU6 Webcam Fix

Arch Linux helper repo for the Dell Latitude 9440 / 9440 2-in-1 IPU6 webcam,
tested with the `ov02c10` sensor and a v4l2loopback device at `/dev/video42`.

This repo does not replace Arch's `libcamera`, does not install packages from
the `archlinux-ipu6-webcam` PR branch, and does not clone unpinned driver code.
It configures the known-good final userspace bridge we verified locally.

## What It Does

- Checks that the IPU6, IVSC, sensor, libcamera, GStreamer, and loopback pieces
  are present.
- Configures `v4l2loopback` as:

  ```text
  /dev/video42
  card label: VirtualCam
  exclusive_caps=1
  ```

- Installs a user systemd service that keeps `VirtualCam` visible to apps.
- Keeps the real IPU6 camera off while idle.
- Starts the real `libcamerasrc` pipeline only while an app is actually using
  `/dev/video42`.
- Switches back to an idle black placeholder after the camera app closes.

The placeholder is intentional. With `v4l2loopback exclusive_caps=1`, the
virtual camera may disappear as a capture device when no writer is attached.
The placeholder keeps browser/app discovery normal without keeping the real
sensor active.

## Target Machine

Known-good target:

- Dell Latitude 9440 / Latitude 9440 2-in-1
- Intel Raptor Lake IPU6 imaging controller, PCI ID `8086:a75d`
- Sensor `ov02c10 19-0036`
- Arch Linux

The installer refuses other models unless you pass `--force`.

## Required Driver Stack

This repo assumes the kernel driver layer is already installed and loadable.
Run:

```bash
./scripts/doctor.sh
```

Expected loaded modules include:

```text
intel_ipu6
intel_ipu6_isys
intel_ipu6_psys
ivsc_csi
ivsc_ace
i2c_ljca
ov02c10
v4l2loopback
```

Expected Arch packages include:

```text
libcamera
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

For IPU6 DKMS drivers, use a trusted package source for your kernel and inspect
the build scripts before installing. This repo intentionally does not vendor or
automatically install that driver layer.

## Install

```bash
./scripts/doctor.sh
./scripts/install.sh
./scripts/test-camera.sh
```

The install script writes:

- `/etc/modprobe.d/v4l2loopback.conf`
- `/etc/modules-load.d/v4l2loopback.conf`
- `~/.local/bin/start-virtualcam`
- `~/.config/systemd/user/virtualcam.service`

It also disables the packaged `v4l2-relayd` service by default because it can
compete for `/dev/video42`. Use `--keep-v4l2-relayd` if you explicitly want to
manage that yourself.

## Browser/App Use

Select `VirtualCam` as the camera. Browser permission prompts still work at the
browser/app layer. This service only sees whether a process opened
`/dev/video42`; it cannot know which website triggered the browser request.

Idle check:

```bash
fuser -v /dev/video42 /dev/video0 /dev/media0
```

Expected idle state:

- `/dev/video42` is held by the placeholder writer.
- `/dev/video0` is not held by the real camera pipeline.
- `wireplumber` may hold `/dev/media0`.

## Uninstall

```bash
./scripts/uninstall.sh
```

To also remove the loopback module config files if they still match this repo:

```bash
./scripts/uninstall.sh --remove-loopback-config
```

## Notes

`libcamera` may log warnings about missing `ov02c10` static properties and an
uncalibrated fallback. Those warnings were present in the working setup and are
not, by themselves, a failure.

