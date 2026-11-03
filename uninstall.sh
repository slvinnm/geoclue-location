#!/usr/bin/env bash
# Download the project's installer and run its restore-before-uninstall flow.

set -Eeuo pipefail

readonly INSTALLER_URL="https://raw.githubusercontent.com/slvinnm/geoclue-location/main/install.sh"
TEMP_DIR=""

info()  { printf '\033[1;34mINFO\033[0m %s\n' "$*"; }
error() { printf '\033[1;31mERROR\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
}
trap cleanup EXIT

find_installer() {
    local script_dir=""

    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
    fi

    if [[ -n "$script_dir" && -f "${script_dir}/install.sh" ]]; then
        INSTALLER_FILE="${script_dir}/install.sh"
        return 0
    fi

    TEMP_DIR="$(mktemp -d)"
    INSTALLER_FILE="${TEMP_DIR}/install.sh"

    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --silent --show-error "$INSTALLER_URL" --output "$INSTALLER_FILE"
    elif command -v wget >/dev/null 2>&1; then
        wget --https-only --quiet "$INSTALLER_URL" --output-document="$INSTALLER_FILE"
    else
        die "Neither curl nor wget is available to download the installer."
    fi
}

main() {
    find_installer
    [[ -s "$INSTALLER_FILE" ]] || die "The installer download is empty."
    bash -n "$INSTALLER_FILE" || die "The downloaded installer failed Bash syntax validation."

    info "Starting the restore-before-uninstall process..."
    bash "$INSTALLER_FILE" --uninstall "$@"
}

main "$@"
