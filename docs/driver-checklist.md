# Driver Checklist

Use this checklist before installing the userspace bridge.

## Hardware

Expected machine:

```bash
cat /sys/class/dmi/id/sys_vendor
cat /sys/class/dmi/id/product_name
```

Expected values include:

```text
Dell Inc.
Latitude 9440
```

Expected IPU controller:

```bash
lspci -nn | grep -i 'image\|ipu\|multimedia'
```

Known-good controller:

```text
Intel Raptor Lake Imaging Signal Processor [8086:a75d]
```

## Kernel Modules

Check:

```bash
lsmod | grep -E 'intel_ipu6|ivsc|ljca|ov02c10|v4l2loopback'
dkms status
```

Expected modules:

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

## Userspace Packages

Required Arch packages:

```bash
pacman -Q base-devel git dkms linux-firmware-intel \
  libcamera libcamera-tools pipewire-libcamera gst-plugin-libcamera \
  gstreamer gst-plugins-base gst-plugins-good \
  v4l2loopback-dkms v4l2loopback-utils v4l-utils \
  wireplumber pipewire psmisc
```

Known-good versions on the machine this repo was built from:

```text
base-devel 1-2
git 2.55.0-1
dkms 3.4.1-1
linux-firmware-intel 20260622-1
libcamera 0.7.1-1
libcamera-tools 0.7.1-1
pipewire-libcamera 1:1.6.7-1
gst-plugin-libcamera 0.7.1-1
gstreamer 1.28.4-2
gst-plugins-base 1.28.4-2
gst-plugins-good 1.28.4-2
v4l2loopback-dkms 0.15.4-1
v4l2loopback-utils 0.15.4-1
v4l-utils 1.32.0-2
wireplumber 0.5.15-1
pipewire 1:1.6.7-1
```

On a new install, `scripts/bootstrap-arch.sh` installs the active kernel header
package and the current AUR IPU6 DKMS package:

```text
intel-ipu6-dkms-git
```

## Direct Camera Test

This should complete without hanging:

```bash
timeout 15 gst-launch-1.0 -q libcamerasrc ! \
  video/x-raw,width=1280,height=720,framerate=30/1 ! \
  fakesink num-buffers=30
```

If this fails, fix the driver/libcamera layer first. The loopback bridge cannot
repair a broken direct `libcamerasrc` path.

## Virtual Camera Test

After `scripts/install.sh`:

```bash
./scripts/test-camera.sh
```

When idle, the real camera should be released:

```bash
fuser -v /dev/video42 /dev/video0 /dev/media0
```

Expected idle state:

```text
/dev/video42: placeholder writer
/dev/video0:  no real camera writer
/dev/media0:  wireplumber may be present
```
