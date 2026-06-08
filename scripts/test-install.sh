#!/bin/zsh
set -euo pipefail

readonly SCRIPT_DIR=${0:A:h}
readonly REPO_DIR=${SCRIPT_DIR:h}
test_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/togglebar-install-test.XXXXXX")
trap '/bin/rm -rf "$test_dir"' EXIT

fail() {
    print -u2 -- "FAIL: $1"
    exit 1
}

launch_agent="$test_dir/launch agent.plist"
app_executable="$test_dir/Applications & Tools/ToggleBar.app/Contents/MacOS/ToggleBar"
"$SCRIPT_DIR/render-install-file.sh" launch-agent "$launch_agent" "$app_executable"
actual_executable=$(/usr/bin/plutil -extract ProgramArguments.0 raw "$launch_agent")
[[ "$actual_executable" == "$app_executable" ]] || fail "LaunchAgent executable path changed during rendering"
[[ "$(/usr/bin/plutil -extract Label raw "$launch_agent")" == "io.github.jbamlee.togglebar" ]] || fail "LaunchAgent label is incorrect"

sudoers_file="$test_dir/togglebar.sudoers"
"$SCRIPT_DIR/render-install-file.sh" sudoers "$sudoers_file" 501
/usr/sbin/visudo -cf "$sudoers_file" >/dev/null
[[ "$(<"$sudoers_file")" == '#501 ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1' ]] || fail "sudoers rule is broader than expected"

set +e
TOGGLEBAR_NONINTERACTIVE=1 "$REPO_DIR/install.sh" >"$test_dir/missing-options.log" 2>&1
missing_options_status=$?
set -e
[[ "$missing_options_status" == "2" ]] || fail "non-interactive installation accepted missing choices"

set +e
TOGGLEBAR_NONINTERACTIVE=1 \
TOGGLEBAR_APP_DIR="relative/path" \
TOGGLEBAR_BIN_DIR="$test_dir/bin" \
TOGGLEBAR_LAUNCH_AT_LOGIN=0 \
TOGGLEBAR_INSTALL_SUDOERS=0 \
"$REPO_DIR/install.sh" >"$test_dir/relative-path.log" 2>&1
relative_path_status=$?
set -e
[[ "$relative_path_status" == "2" ]] || fail "installer accepted a relative destination"

app_dir="$test_dir/Applications & Tools"
bin_dir="$test_dir/bin"
TOGGLEBAR_NONINTERACTIVE=1 \
TOGGLEBAR_APP_DIR="$app_dir" \
TOGGLEBAR_BIN_DIR="$bin_dir" \
TOGGLEBAR_LAUNCH_AT_LOGIN=0 \
TOGGLEBAR_INSTALL_SUDOERS=0 \
"$REPO_DIR/install.sh"

[[ -x "$app_dir/ToggleBar.app/Contents/MacOS/ToggleBar" ]] || fail "app executable was not installed"
[[ -x "$bin_dir/togglebar" ]] || fail "CLI executable was not installed"
/usr/bin/codesign --verify --deep --strict "$app_dir/ToggleBar.app"

print -- "PASS: installer behavior"
