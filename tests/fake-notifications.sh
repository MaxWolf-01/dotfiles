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
    # A config of its own: nix's dbus-daemon looks for its session config under /etc, which only NixOS has.
    cat >"$dir/bus.conf" <<CONF
<busconfig>
  <type>session</type>
  <listen>unix:path=$dir/bus</listen>
  <policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy>
</busconfig>
CONF
    local bus ready
    exec {bus}< <(exec dbus-daemon --config-file="$dir/bus.conf" --nofork --print-address=1)
    fake_notifications_pids+=($!)
    # The deadlines are backstops for a daemon or a fake that never answers.
    read -r -t 5 -u "$bus" DBUS_SESSION_BUS_ADDRESS || { fail "the private bus starts"; finish; }
    export DBUS_SESSION_BUS_ADDRESS
    exec {ready}< <(exec uv run --script --quiet "$(dirname "${BASH_SOURCE[0]}")/fake-notifications.py" "$fake_notifications_log")
    fake_notifications_pids+=($!)
    read -r -t 30 -u "$ready" _ || { fail "the fake notification service starts"; finish; }
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

# Wait up to <secs> for the number of notifications on screen to become <count>: checked as each event lands in the
# log, which tail follows by inotify; the deadline is the backstop for a count that never comes.
await_shown() { # <count> <secs>
    local log tailer end=$((SECONDS + $2)) rc=1
    # Following before the first count, so an event landing between the two is still heard.
    exec {log}< <(exec tail -n 0 -f "$fake_notifications_log")
    tailer=$!
    while :; do
        [ "$(shown | grep -c .)" -eq "$1" ] && { rc=0; break; }
        [ $SECONDS -lt $end ] && read -r -t $((end - SECONDS)) -u "$log" _ || break
    done
    kill "$tailer" 2>/dev/null
    exec {log}<&-
    return $rc
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
