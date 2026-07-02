#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/common.sh
source "$script_dir/common.sh"

required_packages=(
  base-devel
  git
  dkms
  linux-firmware-intel
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
)

required_commands=(
  gst-launch-1.0
  fuser
  v4l2-ctl
  systemctl
)

expected_modules=(
  intel_ipu6
  intel_ipu6_isys
  intel_ipu6_psys
  ivsc_csi
  ivsc_ace
  i2c_ljca
  ov02c10
  v4l2loopback
)

section() {
  printf '\n== %s ==\n' "$1"
}

ok() {
  printf 'ok: %s\n' "$1"
}

warn() {
  printf 'warn: %s\n' "$1"
}

section "Machine"
printf 'model: %s\n' "$(print_model)"
printf 'kernel: %s\n' "$(uname -r)"
if is_latitude_9440; then
  ok "Dell Latitude 9440 detected"
else
  warn "not detected as Dell Latitude 9440"
fi

section "Commands"
for command_name in "${required_commands[@]}"; do
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name"
  else
    warn "missing command $command_name"
  fi
done

section "Arch Packages"
if command -v pacman >/dev/null 2>&1; then
  for package in "${required_packages[@]}"; do
    if pacman -Q "$package" >/dev/null 2>&1; then
      pacman -Q "$package"
    else
      warn "missing package $package"
    fi
  done
else
  warn "pacman not found"
fi

section "Kernel Headers"
if command -v pacman >/dev/null 2>&1; then
  module_dir=/usr/lib/modules/$(uname -r)
  if [[ -r "$module_dir/pkgbase" ]]; then
    kernel_pkgbase=$(<"$module_dir/pkgbase")
    header_package=${kernel_pkgbase}-headers
    if pacman -Q "$header_package" >/dev/null 2>&1; then
      pacman -Q "$header_package"
    else
      warn "missing active kernel headers package $header_package"
    fi
  else
    warn "cannot detect active kernel package from $module_dir/pkgbase"
  fi
fi

section "Kernel Modules"
for module in "${expected_modules[@]}"; do
  if lsmod | awk '{print $1}' | grep -qx "$module"; then
    ok "$module loaded"
  else
    warn "$module not loaded"
  fi
done

section "DKMS"
if command -v dkms >/dev/null 2>&1; then
  dkms_status=$(dkms status 2>/dev/null || true)
  printf '%s\n' "$dkms_status"
  if grep -Eiq '(^|/)(intel-)?ipu6|ipu6-drivers' <<<"$dkms_status"; then
    ok "IPU6 DKMS provider found"
  else
    warn "no IPU6 DKMS provider found; bootstrap installs intel-ipu6-dkms-git from AUR"
  fi
else
  warn "dkms not found"
fi

section "Video Devices"
if command -v v4l2-ctl >/dev/null 2>&1; then
  v4l2-ctl --list-devices || true
  if [[ -e /dev/video42 ]]; then
    printf '\n/dev/video42:\n'
    v4l2-ctl -d /dev/video42 --all || true
  else
    warn "/dev/video42 does not exist"
  fi
fi

section "libcamera"
if command -v cam >/dev/null 2>&1; then
  timeout 10 cam -l || true
else
  warn "cam not found; install libcamera tools if available"
fi

section "Service"
systemctl --user status virtualcam.service --no-pager || true

section "Device Users"
fuser -v /dev/video42 /dev/video0 /dev/media0 || true
