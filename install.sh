#!/usr/bin/env bash
# Install or uninstall geoclue-location on Arch Linux and Arch-based systems.

set -Eeuo pipefail

readonly REPOSITORY_RAW_URL="https://raw.githubusercontent.com/slvinnm/geoclue-location/main/geoclue-location"
readonly APPLICATION_NAME="geoclue-location"
readonly DEFAULT_BIN_DIR="/usr/local/bin"
readonly BACKUP_DIR="/var/lib/geoclue-location-manager/installer-backups"

BIN_DIR="$DEFAULT_BIN_DIR"
INSTALL_DEPENDENCIES=1
UNINSTALL=0
TEMP_DIR=""
TEMP_TARGET=""

info()    { printf '\033[1;34mINFO\033[0m %s\n' "$*"; }
success() { printf '\033[1;32mOK\033[0m   %s\n' "$*"; }
warn()    { printf '\033[1;33mWARN\033[0m %s\n' "$*" >&2; }
error()   { printf '\033[1;31mERROR\033[0m %s\n' "$*" >&2; }
die()     { error "$*"; exit 1; }

usage() {
    cat <<USAGE
${APPLICATION_NAME} installer

Usage:
  bash install.sh [options]
  curl -fsSL https://raw.githubusercontent.com/slvinnm/geoclue-location/main/install.sh | bash

Options:
  --bin-dir DIR   Install the command into DIR (default: ${DEFAULT_BIN_DIR}).
  --no-deps       Do not install the GeoClue package when it is missing.
  --uninstall     Remove the installed command (does not remove GeoClue settings).
  -h, --help      Show this help.

The installer installs only the ${APPLICATION_NAME} command. It does not set
coordinates, change GeoClue providers, or modify /etc/geoclue/geoclue.conf.
USAGE
}

cleanup() {
    if [[ -n "$TEMP_TARGET" ]]; then
        as_bin_owner rm -f -- "$TEMP_TARGET" >/dev/null 2>&1 || true
    fi
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
}
trap cleanup EXIT

as_root() {
    if (( EUID == 0 )); then
        "$@"
    else
        command -v sudo >/dev/null 2>&1 || die "sudo is required to install files under ${BIN_DIR}."
        sudo -- "$@"
    fi
}

as_bin_owner() {
    local probe="$BIN_DIR"
    while [[ ! -e "$probe" ]]; do
        probe="$(dirname -- "$probe")"
    done

    if [[ -w "$probe" ]]; then
        "$@"
    else
        as_root "$@"
    fi
}

parse_args() {
    while (($#)); do
        case "$1" in
            --bin-dir)
                (($# >= 2)) || die "--bin-dir requires a directory."
                BIN_DIR="$2"
                shift 2
                ;;
            --no-deps)
                INSTALL_DEPENDENCIES=0
                shift
                ;;
            --uninstall)
                UNINSTALL=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "Unknown option: $1 (use --help for usage)."
                ;;
        esac
    done

    [[ "$BIN_DIR" == /* ]] || die "Installation directory must be an absolute path: ${BIN_DIR}"
    [[ -n "$BIN_DIR" && "$BIN_DIR" != "/" ]] || die "Invalid installation directory: ${BIN_DIR}"
}

require_arch() {
    command -v pacman >/dev/null 2>&1 || die "pacman was not found. This installer supports Arch Linux and Arch-based distributions."
}

is_managed_command() {
    local file="$1"
    [[ -f "$file" ]] && grep -Fq '# Manage a static GeoClue location on Arch Linux.' "$file"
}

uninstall_command() {
    local target="${BIN_DIR}/${APPLICATION_NAME}"

    if [[ ! -e "$target" && ! -L "$target" ]]; then
        info "${APPLICATION_NAME} is not installed in ${BIN_DIR}."
        return 0
    fi

    is_managed_command "$target" || die "Refusing to remove ${target}: it does not look like this project's command."

    as_bin_owner rm -f -- "$target"
    success "Removed ${target}."
    warn "GeoClue configuration and backups were left untouched."
}

ensure_geoclue_package() {
    if pacman -Q geoclue >/dev/null 2>&1; then
        success "GeoClue package is already installed."
        return 0
    fi

    if (( INSTALL_DEPENDENCIES == 0 )); then
        warn "GeoClue is not installed. Continuing because --no-deps was specified."
        return 0
    fi

    info "GeoClue is missing; installing it with pacman."
    as_root pacman -S --needed geoclue
    pacman -Q geoclue >/dev/null 2>&1 || die "GeoClue installation could not be verified."
    success "GeoClue installed."
}

get_source_file() {
    local script_dir=""

    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
    fi

    if [[ -n "$script_dir" && -f "${script_dir}/${APPLICATION_NAME}" ]]; then
        SOURCE_FILE="${script_dir}/${APPLICATION_NAME}"
        return 0
    fi

    TEMP_DIR="$(mktemp -d)"
    SOURCE_FILE="${TEMP_DIR}/${APPLICATION_NAME}"

    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --silent --show-error "$REPOSITORY_RAW_URL" --output "$SOURCE_FILE"
    elif command -v wget >/dev/null 2>&1; then
        wget --https-only --quiet "$REPOSITORY_RAW_URL" --output-document="$SOURCE_FILE"
    else
        die "Neither curl nor wget is available to download ${APPLICATION_NAME}."
    fi
}

install_command() {
    local target="${BIN_DIR}/${APPLICATION_NAME}"
    local timestamp

    get_source_file

    [[ -s "$SOURCE_FILE" ]] || die "The command source is empty: ${SOURCE_FILE}"
    is_managed_command "$SOURCE_FILE" || die "Downloaded/local source does not match the expected ${APPLICATION_NAME} script."
    bash -n "$SOURCE_FILE" || die "The ${APPLICATION_NAME} script failed Bash syntax validation."

    ensure_geoclue_package

    if [[ -e "$target" || -L "$target" ]]; then
        is_managed_command "$target" || die "Refusing to overwrite ${target}: it does not look like this project's command."

        timestamp="$(date +%Y%m%d-%H%M%S)-$$"
        as_root install -d -o root -g root -m 700 "$BACKUP_DIR"
        as_root cp -a -- "$target" "${BACKUP_DIR}/${APPLICATION_NAME}-${timestamp}"
        info "Previous ${APPLICATION_NAME} version backed up to ${BACKUP_DIR}/${APPLICATION_NAME}-${timestamp}."
    fi

    as_bin_owner install -d -m 755 "$BIN_DIR"
    TEMP_TARGET="${BIN_DIR}/.${APPLICATION_NAME}.install.$$"
    as_bin_owner install -m 755 -- "$SOURCE_FILE" "$TEMP_TARGET"
    as_bin_owner mv -f -- "$TEMP_TARGET" "$target"
    TEMP_TARGET=""

    success "Installed ${target}."
    printf '\nRun:\n  %s\n\n' "$APPLICATION_NAME"
    info "The installer did not change your location or GeoClue provider settings."
    info "To configure a static location, run: ${APPLICATION_NAME}"
    info "To uninstall the command later, run this installer with --uninstall."
}

main() {
    parse_args "$@"
    require_arch

    if (( UNINSTALL )); then
        uninstall_command
    else
        install_command
    fi
}

main "$@"
