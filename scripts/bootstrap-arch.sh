#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/common.sh
source "$script_dir/common.sh"

force=0
install_aur=1
install_bridge=1
system_upgrade=1
aur_helper=auto
aur_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/dell-9440-ipu6-aur

aur_packages=(
  intel-ipu6-dkms-git
)

usage() {
  cat <<'USAGE'
Usage: scripts/bootstrap-arch.sh [options]

Installs the Arch packages, current-kernel headers, IPU6 DKMS driver package,
loopback bridge config, and user virtualcam.service needed for this repo.

Options:
  --force                 Run even if this is not detected as Latitude 9440.
  --no-aur                Skip AUR IPU6 DKMS installation.
  --aur-helper NAME       Use a specific AUR helper, for example yay or paru.
                          Default: auto-detect yay/paru, otherwise makepkg.
  --aur-dir PATH          Cache AUR package clones in PATH.
                          Default: $XDG_CACHE_HOME/dell-9440-ipu6-aur.
  --with-ipu6-hal         Also install Intel IPU6 HAL/icamerasrc AUR packages.
                          Not required for this repo's libcamera bridge.
  --no-system-upgrade     Use pacman -S instead of pacman -Syu.
  --no-bridge             Install packages/drivers only; skip scripts/install.sh.
  -h, --help              Show this help.
USAGE
}

while (($#)); do
  case "$1" in
    --force)
      force=1
      ;;
    --no-aur)
      install_aur=0
      ;;
    --aur-helper)
      if (($# < 2)); then
        printf '%s requires a value\n' "$1" >&2
        exit 2
      fi
      aur_helper=$2
      shift
      ;;
    --aur-dir)
      if (($# < 2)); then
        printf '%s requires a value\n' "$1" >&2
        exit 2
      fi
      aur_dir=$2
      shift
      ;;
    --with-ipu6-hal)
      aur_packages+=(
        intel-ipu6-camera-bin
        intel-ipu6-camera-hal-git
        icamerasrc-git
      )
      ;;
    --no-system-upgrade)
      system_upgrade=0
      ;;
    --no-bridge)
      install_bridge=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if (( EUID == 0 )); then
  printf 'Run this script as your normal user, not root. It uses sudo only for pacman/system files.\n' >&2
  exit 1
fi

if (( ! force )) && ! is_latitude_9440; then
  printf 'Refusing bootstrap: detected model is "%s"\n' "$(print_model)" >&2
  printf 'Pass --force if you intentionally want to install anyway.\n' >&2
  exit 1
fi

require_command pacman
require_command sudo

kernel_headers_package() {
  local module_dir pkgbase
  module_dir=/usr/lib/modules/$(uname -r)

  if [[ -r "$module_dir/pkgbase" ]]; then
    pkgbase=$(<"$module_dir/pkgbase")
  else
    pkgbase=$(uname -r)
    pkgbase=${pkgbase%%-*}
  fi

  printf '%s-headers\n' "$pkgbase"
}

install_official_packages() {
  local header_package
  local pacman_args=(-S --needed)
  local packages=(
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

  header_package=$(kernel_headers_package)
  if pacman -Si "$header_package" >/dev/null 2>&1; then
    packages+=("$header_package")
  else
    printf 'warn: could not find package %s; install headers for kernel %s manually if DKMS fails\n' \
      "$header_package" "$(uname -r)" >&2
  fi

  if (( system_upgrade )); then
    pacman_args=(-Syu --needed)
  fi

  sudo_cmd pacman "${pacman_args[@]}" "${packages[@]}"
}

detect_aur_helper() {
  if [[ "$aur_helper" != auto ]]; then
    command -v "$aur_helper" 2>/dev/null || true
    return 0
  fi

  if command -v paru >/dev/null 2>&1; then
    command -v paru
  elif command -v yay >/dev/null 2>&1; then
    command -v yay
  fi
}

install_aur_with_makepkg() {
  local package target

  require_command git
  require_command makepkg
  mkdir -p "$aur_dir"

  for package in "${aur_packages[@]}"; do
    target=$aur_dir/$package

    if [[ -d "$target/.git" ]]; then
      git -C "$target" pull --ff-only
    else
      git clone "https://aur.archlinux.org/${package}.git" "$target"
    fi

    printf '\nReview the AUR package before building:\n  %s/PKGBUILD\n' "$target"
    if [[ -t 0 ]]; then
      read -r -p 'Press Enter to run makepkg -si, or Ctrl-C to stop. ' _
    fi

    (cd "$target" && makepkg -si --needed)
  done
}

install_aur_packages() {
  local helper_path

  if (( ! install_aur )); then
    printf 'Skipping AUR IPU6 driver installation.\n'
    return 0
  fi

  helper_path=$(detect_aur_helper)
  if [[ -n "$helper_path" ]]; then
    "$helper_path" -S --needed "${aur_packages[@]}"
  else
    install_aur_with_makepkg
  fi
}

install_bridge_files() {
  local install_args=()

  if (( ! install_bridge )); then
    printf 'Skipping bridge installation.\n'
    return 0
  fi

  if (( force )); then
    install_args+=(--force)
  fi

  "$script_dir/install.sh" "${install_args[@]}"
}

install_official_packages
install_aur_packages
install_bridge_files

cat <<'DONE'

Bootstrap complete.

Next:
  1. Reboot if pacman upgraded the kernel or DKMS installed new modules.
  2. Run ./scripts/doctor.sh
  3. Run ./scripts/test-camera.sh
  4. Select VirtualCam in the browser/app.
DONE
