#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.11"
# dependencies = ["jeepney"]
# ///
"""A stand-in for the desktop's notification service (org.freedesktop.Notifications), on whatever session bus
DBUS_SESSION_BUS_ADDRESS names. tests/fake-notifications.sh starts it on a private bus; a test never runs it alone.

It writes one JSON line per event to the file given as its argument:

    {"event": "notify", "id", "app", "summary", "body", "actions": {key: label}, "urgency", "replaces"}
    {"event": "close", "id", "by": "caller" | "user"}

and prints "ready" once it holds the service's name. A test plays the user through two methods of its own, on
interface dev.fake.Notifications: Click(u id, s action) invokes the action and closes the notification, as GNOME
does; Dismiss(u id) closes it.
"""

import json
import sys

from jeepney import DBusAddress, HeaderFields, MessageType, new_error, new_method_return, new_signal
from jeepney.bus_messages import message_bus
from jeepney.io.blocking import open_dbus_connection

NAME = "org.freedesktop.Notifications"
PATH = "/org/freedesktop/Notifications"
EMITTER = DBusAddress(PATH, interface=NAME)

# Why a notification closed, by the spec's codes.
DISMISSED, CLOSED_BY_CALL = 2, 3


def main(log_path: str) -> None:
    conn = open_dbus_connection(bus="SESSION")
    conn.send_and_get_reply(message_bus.RequestName(NAME, 4))  # 4: do not queue behind another owner
    print("ready", flush=True)
    open_ids: set[int] = set()
    next_id = 1

    def log(record: dict) -> None:
        with open(log_path, "a") as f:
            f.write(json.dumps(record) + "\n")

    def closed(id: int, reason: int) -> None:
        if id in open_ids:
            open_ids.discard(id)
            log({"event": "close", "id": id, "by": "caller" if reason == CLOSED_BY_CALL else "user"})
            conn.send(new_signal(EMITTER, "NotificationClosed", "uu", (id, reason)))

    while True:
        msg = conn.receive()
        if msg.header.message_type != MessageType.method_call:
            continue
        member = msg.header.fields.get(HeaderFields.member)
        if member == "Notify":
            app, replaces, _icon, summary, body, actions, hints, _timeout = msg.body
            id = replaces if replaces in open_ids else next_id
            if id == next_id:
                next_id += 1
            open_ids.add(id)
            urgency = hints.get("urgency", (None, None))[1]
            log({"event": "notify", "id": id, "app": app, "summary": summary, "body": body,
                 "actions": dict(zip(actions[::2], actions[1::2])), "urgency": urgency,
                 "replaces": replaces})  # fmt: skip
            conn.send(new_method_return(msg, "u", (id,)))
        elif member == "CloseNotification":
            closed(msg.body[0], CLOSED_BY_CALL)
            conn.send(new_method_return(msg))
        elif member == "GetCapabilities":
            conn.send(new_method_return(msg, "as", (["actions", "body"],)))
        elif member == "GetServerInformation":
            conn.send(new_method_return(msg, "ssss", ("fake", "dotfiles", "1", "1.2")))
        elif member == "Click":
            id, action = msg.body
            if id in open_ids:
                conn.send(new_signal(EMITTER, "ActionInvoked", "us", (id, action)))
            closed(id, DISMISSED)
            conn.send(new_method_return(msg))
        elif member == "Dismiss":
            closed(msg.body[0], DISMISSED)
            conn.send(new_method_return(msg))
        else:
            conn.send(new_error(msg, "org.freedesktop.DBus.Error.UnknownMethod"))


if __name__ == "__main__":
    main(sys.argv[1])
