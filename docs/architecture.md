# Architecture

The Dell Latitude 9440 webcam stack has four layers.

## 1. Kernel And Sensor Drivers

The hardware camera is an Intel IPU6 path with IVSC and an `ov02c10` sensor.
The expected loaded modules are:

```text
intel_ipu6
intel_ipu6_isys
intel_ipu6_psys
ivsc_csi
ivsc_ace
i2c_ljca
ov02c10
```

This layer is kernel-version sensitive. This repo checks it but does not vendor
or install IPU6 DKMS sources.

## 2. libcamera And GStreamer

The working direct capture path is:

```text
libcamerasrc -> videoconvert -> videoscale -> YUY2 1280x720@30
```

`libcamera` may warn that `ov02c10.yaml` or static sensor properties are
missing. The tested setup still streams using the simple pipeline and
uncalibrated fallback.

## 3. v4l2loopback Compatibility Device

Many browsers and apps expect a normal V4L2 camera. The repo creates:

```text
/dev/video42
VirtualCam
exclusive_caps=1
```

The real IPU6 camera is bridged into that loopback device with GStreamer.

## 4. On-Demand Supervisor

If no writer is attached, `exclusive_caps=1` can make the virtual camera stop
appearing as a capture device. To preserve normal app discovery without keeping
the real camera active, the user service does this:

```text
idle:
  black placeholder -> /dev/video42

while an app consumes /dev/video42:
  libcamerasrc -> /dev/video42

after the app closes:
  black placeholder -> /dev/video42
```

The supervisor detects consumers with `fuser /dev/video42`. It cannot know
which website triggered browser camera access; browser permission prompts still
happen in the browser.

