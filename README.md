# ToggleBar

A personal macOS menu bar toggle hub. Register frequently changed settings once and
control them from a menu bar panel or the command line.

```text
toggles.json          <- data source at ~/.config/togglebar/toggles.json
Sources/ToggleKit     <- config, status, commands, and privilege handling
Sources/togglebar     <- CLI frontend
Sources/ToggleBarApp  <- SwiftUI menu bar frontend
```

## Install

Run the installer on macOS 13 or newer:

```sh
./install.sh
```

The installer collects every choice before it builds or changes the system. It asks for:

- the app installation directory (default: `~/Applications`)
- the CLI installation directory (default: `~/.local/bin`)
- whether ToggleBar should launch at login
- whether the two `pmset disablesleep` commands may run without a password

The passwordless option installs a sudoers rule for the current numeric user ID and only
allows `/usr/bin/pmset -a disablesleep 0` and `/usr/bin/pmset -a disablesleep 1`.

### Environment-driven installation

Automation can provide the same choices as environment variables:

```sh
TOGGLEBAR_NONINTERACTIVE=1 \
TOGGLEBAR_APP_DIR="$HOME/Applications" \
TOGGLEBAR_BIN_DIR="$HOME/.local/bin" \
TOGGLEBAR_LAUNCH_AT_LOGIN=1 \
TOGGLEBAR_INSTALL_SUDOERS=0 \
./install.sh
```

`TOGGLEBAR_LAUNCH_AT_LOGIN` and `TOGGLEBAR_INSTALL_SUDOERS` must be explicitly set to
`0` or `1` in non-interactive mode. A non-interactive sudoers installation only proceeds
when `sudo` credentials have already been established; it never opens a password prompt.
Setting `CI` or running without a terminal also selects non-interactive mode.

If the CLI directory is not already on `PATH`, add it to your shell configuration.

### Build without installing

```sh
./build.sh
open ToggleBar.app
```

Build output remains inside the repository. `build.sh` does not modify user installation
directories, LaunchAgents, or sudoers.

## Add a toggle

Click the menu bar icon and select **Edit config**. Each entry in
`~/.config/togglebar/toggles.json` has this shape:

```json
{
  "id": "do-not-disturb",
  "title": "Focus",
  "group": "System",
  "icon": "🌙",
  "subtitle": "do not disturb",
  "check": "shortcuts run 'DND status' ... && echo on || echo off",
  "on": "shortcuts run 'DND on'",
  "off": "shortcuts run 'DND off'",
  "needsRoot": false
}
```

| Field | Meaning |
|---|---|
| `check` | Shell command that prints `on` when active |
| `on` / `off` | Shell commands that change the state |
| `needsRoot` | Run state changes with administrator privileges |
| `group`, `icon`, `subtitle` | Panel presentation |

Changes are picked up the next time the panel opens.

## CLI

```sh
togglebar list
togglebar status stay-awake
togglebar toggle stay-awake
togglebar on stay-awake
togglebar off tailscale
```

## Uninstall optional system integration

Disable login launch:

```sh
launchctl bootout "gui/$(id -u)/io.github.jbamlee.togglebar"
rm "$HOME/Library/LaunchAgents/io.github.jbamlee.togglebar.plist"
```

Remove the optional passwordless rule:

```sh
sudo rm /private/etc/sudoers.d/togglebar
sudo visudo -c
```

## Installer tests

```sh
./scripts/test-install.sh
```
