#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR=${0:A:h}
readonly APP_NAME="ToggleBar.app"
readonly CLI_NAME="togglebar"
readonly LABEL="io.github.jbamlee.togglebar"
readonly SUDOERS_PATH="/private/etc/sudoers.d/togglebar"

fail() {
    print -u2 -- "error: $1"
    exit "${2:-1}"
}

require_boolean() {
    local name=$1
    local value=$2
    [[ "$value" == "0" || "$value" == "1" ]] || fail "$name must be 0 or 1" 2
}

prompt_directory() {
    local label=$1
    local default_value=$2
    local reply
    read "reply?$label [$default_value]: "
    print -r -- "${reply:-$default_value}"
}

prompt_boolean() {
    local label=$1
    local default_value=$2
    local reply
    local hint="y/N"
    [[ "$default_value" == "1" ]] && hint="Y/n"

    while true; do
        read "reply?$label [$hint]: "
        reply=${reply:l}
        case "$reply" in
        y|yes) print -r -- "1"; return ;;
        n|no) print -r -- "0"; return ;;
        "") print -r -- "$default_value"; return ;;
        *) print -u2 -- "Enter y or n." ;;
        esac
    done
}

validate_directory() {
    local name=$1
    local value=$2
    [[ "$value" == /* ]] || fail "$name must be an absolute path" 2
    [[ "$value" != "/" ]] || fail "$name cannot be the filesystem root" 2
}

noninteractive=0
if [[ -n "${TOGGLEBAR_NONINTERACTIVE+x}" ]]; then
    require_boolean "TOGGLEBAR_NONINTERACTIVE" "$TOGGLEBAR_NONINTERACTIVE"
fi
if [[ "${TOGGLEBAR_NONINTERACTIVE:-0}" == "1" || -n "${CI:-}" || ! -t 0 ]]; then
    noninteractive=1
fi

if [[ "$noninteractive" == "1" ]]; then
    [[ -n "${TOGGLEBAR_LAUNCH_AT_LOGIN+x}" ]] || fail "TOGGLEBAR_LAUNCH_AT_LOGIN is required in non-interactive mode" 2
    [[ -n "${TOGGLEBAR_INSTALL_SUDOERS+x}" ]] || fail "TOGGLEBAR_INSTALL_SUDOERS is required in non-interactive mode" 2
    app_dir=${TOGGLEBAR_APP_DIR:-${HOME:?HOME is required}/Applications}
    bin_dir=${TOGGLEBAR_BIN_DIR:-${HOME:?HOME is required}/.local/bin}
    launch_at_login=$TOGGLEBAR_LAUNCH_AT_LOGIN
    install_sudoers=$TOGGLEBAR_INSTALL_SUDOERS
else
    app_dir=${TOGGLEBAR_APP_DIR:-}
    bin_dir=${TOGGLEBAR_BIN_DIR:-}
    launch_at_login=${TOGGLEBAR_LAUNCH_AT_LOGIN:-}
    install_sudoers=${TOGGLEBAR_INSTALL_SUDOERS:-}

    [[ -n "$app_dir" ]] || app_dir=$(prompt_directory "App directory" "${HOME:?HOME is required}/Applications")
    [[ -n "$bin_dir" ]] || bin_dir=$(prompt_directory "CLI directory" "$HOME/.local/bin")
    [[ -n "$launch_at_login" ]] || launch_at_login=$(prompt_boolean "Launch ToggleBar at login?" 1)
    [[ -n "$install_sudoers" ]] || install_sudoers=$(prompt_boolean "Allow the two pmset commands without a password?" 0)
fi

app_dir=${app_dir%/}
bin_dir=${bin_dir%/}
require_boolean "TOGGLEBAR_LAUNCH_AT_LOGIN" "$launch_at_login"
require_boolean "TOGGLEBAR_INSTALL_SUDOERS" "$install_sudoers"
validate_directory "TOGGLEBAR_APP_DIR" "$app_dir"
validate_directory "TOGGLEBAR_BIN_DIR" "$bin_dir"

readonly APP_PATH="$app_dir/$APP_NAME"
readonly APP_EXECUTABLE="$APP_PATH/Contents/MacOS/ToggleBar"
readonly CLI_PATH="$bin_dir/$CLI_NAME"
readonly LAUNCH_AGENT_PATH="${HOME:?HOME is required}/Library/LaunchAgents/$LABEL.plist"
readonly USER_UID=$(/usr/bin/id -u)
[[ "$APP_PATH" != "$SCRIPT_DIR/$APP_NAME" ]] || fail "TOGGLEBAR_APP_DIR cannot be the repository directory" 2
[[ "$CLI_PATH" != "$SCRIPT_DIR/.build/release/$CLI_NAME" ]] || fail "TOGGLEBAR_BIN_DIR cannot be the release build directory" 2

print -- ""
print -- "ToggleBar installation plan"
print -- "  App:                $APP_PATH"
print -- "  CLI:                $CLI_PATH"
print -- "  Launch at login:    $([[ "$launch_at_login" == "1" ]] && print yes || print no)"
print -- "  Passwordless pmset: $([[ "$install_sudoers" == "1" ]] && print yes || print no)"
[[ "$launch_at_login" == "1" ]] && print -- "  LaunchAgent:        $LAUNCH_AGENT_PATH"
[[ "$install_sudoers" == "1" ]] && print -- "  sudoers rule:       $SUDOERS_PATH (UID $USER_UID)"
print -- ""

if [[ "$noninteractive" == "0" ]]; then
    confirmed=$(prompt_boolean "Continue with this plan?" 1)
    [[ "$confirmed" == "1" ]] || fail "installation cancelled" 2
fi

if [[ "$install_sudoers" == "1" ]]; then
    if [[ "$noninteractive" == "1" ]]; then
        /usr/bin/sudo -n true || fail "sudo authentication is required before non-interactive installation" 2
    else
        /usr/bin/sudo -v
    fi
fi

"$SCRIPT_DIR/build.sh"

/bin/mkdir -p "$app_dir" "$bin_dir"
/bin/rm -rf "$APP_PATH"
/usr/bin/ditto "$SCRIPT_DIR/$APP_NAME" "$APP_PATH"
/usr/bin/install -m 0755 "$SCRIPT_DIR/.build/release/$CLI_NAME" "$CLI_PATH"
/usr/bin/codesign --verify --deep --strict "$APP_PATH"

launch_agent_candidate=""
sudoers_candidate=""
sudoers_backup=""
cleanup() {
    [[ -z "$launch_agent_candidate" ]] || /bin/rm -f "$launch_agent_candidate"
    [[ -z "$sudoers_candidate" ]] || /bin/rm -f "$sudoers_candidate"
    [[ -z "$sudoers_backup" ]] || /bin/rm -f "$sudoers_backup"
}
trap cleanup EXIT

if [[ "$launch_at_login" == "1" ]]; then
    /bin/mkdir -p "${LAUNCH_AGENT_PATH:h}"
    launch_agent_candidate=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/togglebar-launch-agent.XXXXXX")
    "$SCRIPT_DIR/scripts/render-install-file.sh" launch-agent "$launch_agent_candidate" "$APP_EXECUTABLE"
    /usr/bin/install -m 0644 "$launch_agent_candidate" "$LAUNCH_AGENT_PATH"
    /bin/launchctl bootout "gui/$USER_UID/$LABEL" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/$USER_UID" "$LAUNCH_AGENT_PATH"
    /bin/launchctl print "gui/$USER_UID/$LABEL" >/dev/null
fi

if [[ "$install_sudoers" == "1" ]]; then
    sudoers_candidate=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/togglebar-sudoers.XXXXXX")
    "$SCRIPT_DIR/scripts/render-install-file.sh" sudoers "$sudoers_candidate" "$USER_UID"

    previous_sudoers=0
    if /usr/bin/sudo /bin/test -f "$SUDOERS_PATH"; then
        previous_sudoers=1
        sudoers_backup=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/togglebar-sudoers-backup.XXXXXX")
        /usr/bin/sudo /bin/cp -p "$SUDOERS_PATH" "$sudoers_backup"
    fi

    /usr/bin/sudo /usr/bin/install -o root -g wheel -m 0440 "$sudoers_candidate" "$SUDOERS_PATH"
    if ! /usr/bin/sudo /usr/sbin/visudo -c >/dev/null ||
       ! /usr/bin/sudo -n -l -- /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1 ||
       ! /usr/bin/sudo -n -l -- /usr/bin/pmset -a disablesleep 1 >/dev/null 2>&1; then
        if [[ "$previous_sudoers" == "1" ]]; then
            /usr/bin/sudo /usr/bin/install -o root -g wheel -m 0440 "$sudoers_backup" "$SUDOERS_PATH"
        else
            /usr/bin/sudo /bin/rm -f "$SUDOERS_PATH"
        fi
        fail "sudoers validation failed; the previous policy was restored"
    fi
fi

print -- ""
print -- "Installation complete."
print -- "  Open app: /usr/bin/open '$APP_PATH'"
print -- "  CLI:      $CLI_PATH"
