#!/bin/zsh
set -euo pipefail

readonly LABEL="io.github.jbamlee.togglebar"

fail() {
    print -u2 -- "error: $1"
    exit 2
}

[[ $# -ge 1 ]] || fail "usage: $0 launch-agent <output> <app-executable> | sudoers <output> <uid>"

case "$1" in
launch-agent)
    [[ $# -eq 3 ]] || fail "launch-agent requires an output path and app executable"
    output=$2
    executable=$3
    [[ "$output" == /* ]] || fail "output path must be absolute"
    [[ "$executable" == /* ]] || fail "app executable path must be absolute"

    /usr/bin/plutil -create xml1 "$output"
    /usr/bin/plutil -insert Label -string "$LABEL" "$output"
    /usr/bin/plutil -insert ProgramArguments -array "$output"
    /usr/bin/plutil -insert ProgramArguments.0 -string "$executable" "$output"
    /usr/bin/plutil -insert RunAtLoad -bool true "$output"
    /bin/chmod 0644 "$output"
    /usr/bin/plutil -lint "$output" >/dev/null
    ;;
sudoers)
    [[ $# -eq 3 ]] || fail "sudoers requires an output path and numeric uid"
    output=$2
    uid=$3
    [[ "$output" == /* ]] || fail "output path must be absolute"
    [[ "$uid" == <-> ]] || fail "uid must be numeric"

    print -r -- "#${uid} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1" > "$output"
    /bin/chmod 0440 "$output"
    /usr/sbin/visudo -cf "$output" >/dev/null
    ;;
*)
    fail "unknown output type: $1"
    ;;
esac
