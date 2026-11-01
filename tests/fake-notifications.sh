# A private session bus holding a stand-in for the desktop's notification service (fake-notifications.py), for a
# test that drives a program raising notifications. Source it after check.sh, then call fake_notifications_start
# <scratch dir>: it exports DBUS_SESSION_BUS_ADDRESS, so whatever the test runs from then on notifies the fake, and
# kills both on exit through fake_notifications_stop, which the caller's EXIT trap runs.

fake_notifications_pids=()

fake_notifications_start() { # <scratch dir>
    local dir="$1/notifications"
    needs dbus-daemon dbus-send notify-send gdbus uv
    mkdir -p "$dir"
    fake_notifications_log="$dir/events.jsonl"
    : >"$fake_notifications_log"
    dbus-daemon --session --nofork --address="unix:path=$dir/bus" --print-address=1 >"$dir/address" &
    fake_notifications_pids+=($!)
    timeout 5 bash -c "until [ -s '$dir/address' ]; do sleep 0.05; done" || { fail "the private bus starts"; finish; }
    export DBUS_SESSION_BUS_ADDRESS
    DBUS_SESSION_BUS_ADDRESS=$(head -1 "$dir/address")
    uv run --script --quiet "$(dirname "${BASH_SOURCE[0]}")/fake-notifications.py" "$fake_notifications_log" >"$dir/ready" &
    fake_notifications_pids+=($!)
    timeout 30 bash -c "until [ -s '$dir/ready' ]; do sleep 0.05; done" || { fail "the fake notification service starts"; finish; }
}

# Also ends every notify holder still up under $XDG_RUNTIME_DIR, by the pid its key's file names.
fake_notifications_stop() {
    local held
    for held in "${XDG_RUNTIME_DIR:-/nonexistent}"/notify/*; do
        [ -f "$held" ] && kill "$(cut -d' ' -f1 "$held")" 2>/dev/null
    done
    [ ${#fake_notifications_pids[@]} -eq 0 ] || kill "${fake_notifications_pids[@]}" 2>/dev/null
}

# The notifications on screen now, one JSON object per line, as the fake logged them.
shown() {
    jq -c -s '(map(select(.event == "close") | .id)) as $closed | .[] | select(.event == "notify" and (.id | IN($closed[]) | not))' \
        "$fake_notifications_log"
}

# Wait up to <secs> for the number of notifications on screen to become <count>.
await_shown() { # <count> <secs>
    local _
    for _ in $(seq $(( $2 * 20 ))); do
        [ "$(shown | grep -c .)" -eq "$1" ] && return 0
        sleep 0.05
    done
    return 1
}

# Play the user: click a notification's action, or dismiss it.
click() { # <id> <action>
    dbus-send --session --print-reply --dest=org.freedesktop.Notifications /org/freedesktop/Notifications \
        dev.fake.Notifications.Click "uint32:$1" "string:$2" >/dev/null
}
dismiss() { # <id>
    dbus-send --session --print-reply --dest=org.freedesktop.Notifications /org/freedesktop/Notifications \
        dev.fake.Notifications.Dismiss "uint32:$1" >/dev/null
}
