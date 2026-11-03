# geoclue-location

A small Bash utility for managing a static GeoClue location on Arch Linux and Arch-based distributions.

It prompts for latitude, longitude, altitude, and accuracy, then applies the location only after confirmation. It uses `/etc/geolocation` and a GeoClue configuration drop-in in `/etc/geoclue/conf.d`; it does not edit the vendor `/etc/geoclue/geoclue.conf` file.

## Installation

### One-line installation

```bash
curl -fsSL https://raw.githubusercontent.com/slvinnm/geoclue-location/main/install.sh | bash
```

The installer:

- Checks that `pacman` is available.
- Installs the `geoclue` package with `pacman` if it is missing (using `sudo` when needed).
- Installs `geoclue-location` into `/usr/local/bin`.
- Validates the command with `bash -n` before installation.
- Backs up a previous version of this same command before updating it.
- Refuses to overwrite an unrelated executable with the same name.

The installer does **not** set a location or modify GeoClue configuration. It only installs the command.

### Install from a cloned repository

```bash
git clone https://github.com/slvinnm/geoclue-location.git
cd geoclue-location
bash install.sh
```

### Optional installer arguments

```bash
bash install.sh --bin-dir "$HOME/.local/bin" --no-deps
```

`--no-deps` skips automatic installation of the `geoclue` package. If you choose a user-owned directory such as `~/.local/bin`, ensure it is in your `PATH`.

## Usage

```bash
geoclue-location          # Interactive setup
geoclue-location set      # Set/update coordinates
geoclue-location status   # Show managed configuration
geoclue-location remove   # Remove the manual static location and manager override
geoclue-location restore  # Restore files backed up before the first setup
geoclue-location help     # Show help
```

The command requests administrator privileges when it needs to modify system files. The first `set` operation backs up the existing `/etc/geolocation` and the manager's own configuration drop-in under `/var/lib/geoclue-location-manager/backups/`.

`remove` removes the static location and this tool's override, while keeping the backup. `restore` puts the backed-up files back. These are separate operations: use `restore` when you want the pre-existing configuration reinstated.

## Update and uninstall

Run the same installer again to update the command:

```bash
curl -fsSL https://raw.githubusercontent.com/slvinnm/geoclue-location/main/install.sh | bash
```

To uninstall the command, run the installer with `--uninstall`:

```bash
curl -fsSL https://raw.githubusercontent.com/slvinnm/geoclue-location/main/install.sh | bash -s -- --uninstall
```

Or, from a cloned repository:

```bash
bash install.sh --uninstall
```

The uninstaller asks for confirmation, then runs `geoclue-location restore` before deleting the command. If restoration fails, the command is kept installed so it remains available for recovery. If a manager drop-in exists but its backup record is missing, uninstallation is stopped rather than risking loss of the original configuration.

When there is no active backup, the uninstaller leaves any existing `/etc/geolocation` file untouched because it cannot prove that the file belongs to this utility. The GeoClue package and archived backups are retained; only the `geoclue-location` command is removed.

## Notes

- Static location is simulated location, not GPS. Applications receive the configured coordinates until they are changed or removed.
- The static source is intended for a fixed location. For a moving device, use a real GPS/NMEA source instead.
- GeoClue may need to be activated by D-Bus; its service is not intended to be enabled with `systemctl enable` on Arch Linux.
- The installer supports Arch Linux and Arch-based distributions using `pacman`.
