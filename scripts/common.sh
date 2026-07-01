#!/usr/bin/env bash

repo_root() {
  local source_dir
  source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
  printf '%s\n' "$source_dir"
}

sudo_cmd() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$1" >&2
    return 1
  fi
}

is_latitude_9440() {
  local product vendor
  vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)

  [[ "$vendor" == *Dell* && "$product" == *"Latitude 9440"* ]]
}

print_model() {
  local vendor product
  vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || printf unknown)
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || printf unknown)
  printf '%s %s\n' "$vendor" "$product"
}

