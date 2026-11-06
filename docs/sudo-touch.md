# sudo by a YubiKey touch

sudo takes a touch of either YubiKey before it asks for the password: on
zephylux through pam_u2f, and on pc and xmg19, in an SSH session from zephylux,
through pam_rssh and a second ssh agent that holds only the YubiKeys' sk keys.
How each half works: `nix/home/sudo-touch.nix` (zephylux) and
`nix/nixos/sudo-touch.nix` (pc and xmg19).

The touch is `sufficient`, ahead of the password, never `required`. With no key
plugged in, no registered key, no forwarded agent, or no touch, sudo asks for
the password as it always did. A key plugged in but left untouched gives up
after its own wait, which nothing here can set, so sudo asks for the touch ten
times in a row before it gets to the password: the time to reach the key is
ten of the key's waits. Each ask on pc and xmg19 raises a notification on the
laptop; on zephylux each prints the cue in the terminal. A machine set up
before the ten asks keeps one on zephylux until `./setup sudo_touch` runs
there again; pc and xmg19 take them with their next `nswitch`.

The keys are the two YubiKeys, the keychain one and the backup. Register both at
every step that registers a key.

## Setting it up

Run `sudo-touch-setup` on zephylux, in a terminal, with both keys at hand. It
registers each key in turn, commits the registrations (`nix/yubikey/u2f_keys`,
`nix/yubikey/sudo-sk-keys.pub`) and the keys' ssh handles (`secrets/creds/raw/`),
then switches zephylux, pc and xmg19 one at a time and checks each: sudo takes a
touch, and, if you choose, still takes the password with the key unplugged.
`sudo-touch-setup --help` says what it needs.

Each step that changes sudo keeps a way back open: the wizard asks for the sudo
password before the change, and sudo's remembered grant is what puts the old
setting back if sudo stops working. Stopped halfway, it runs again from the
start and skips what is done.

What is registered is public data: a credential id and a public key per
YubiKey. `u2f_keys` is bound to the laptop's hostname (pam_u2f's default origin
is `pam://<hostname>`), so a reinstall under another hostname registers again:
delete `~/.local/state/sudo-touch-setup/` and run the wizard. A reinstall that
restores the ssh handles from `secrets/creds/raw/` into `~/.ssh/` needs no new
ones; without them, delete the handles' lines from `sudo-sk-keys.pub` first.

## When it does not work

The password still works, so sudo is not locked; the touch is just not taken.

- **No blink at all on pc or xmg19.** sudo there reads the forwarded agent
  from `~/.ssh/sk-agent.sock`, which each login from the laptop links
  (`nix/nixos/sudo-touch-login.zsh`), while `SSH_AUTH_SOCK` stays on the
  host's own agent for git. `SSH_AUTH_SOCK=~/.ssh/sk-agent.sock ssh-add -L` on
  the host: an error or no sk keys means the link points at a connection that
  is gone, or no login has linked it since the switch. Open a new `ssh pc`; a
  tmux started earlier finds the new link too.
- **A blink, a touch, and still the password prompt.** pam_rssh refused the
  signature. `journalctl -b _COMM=sudo` on that host says why; for more, set
  `security.pam.rssh.settings.loglevel = "debug";` in `nix/nixos/sudo-touch.nix`
  and `nswitch`. `tests/sudo-touch/agent-to-pam.test` drives the same PAM line
  with a software security key, which tells a problem with the setup from one
  with the YubiKey.
- **On zephylux, no "Please touch the device."** `ls -l ~/.config/Yubico/u2f_keys`
  (missing: the wizard has not committed the registration, or `hmswitch` has
  not run since), then add `debug` to the first pam_u2f line in `/etc/pam.d/sudo`.

## Two sudos at once

One agent on zephylux answers both pc and xmg19, and ssh-agent handles one
request at a time. While one sudo waits for a touch, a sudo on the other
host waits behind it and shows nothing, not even its touch prompt; touch
once for each, in the order they asked. Ending the first sudo's ssh session
does not free the agent, which keeps waiting on the key; neither does
Ctrl-C, which a touch wait ignores. A restart of the agent frees only the ask
in flight, since each sudo then asks the restarted agent again. What frees
them all, each waiting sudo going on to its password:

```bash
systemctl --user stop ssh-sk-agent    # on zephylux; start it again once the sudos have moved on
```

Seen 2026-11-01 during the rollout, when sudo asked once: pc's `nswitch`
waited with a blank screen behind xmg19's pending sudo until the agent was
restarted.

## Backing out

- **zephylux.** `/etc/pam.d/sudo` as it was before the wizard changed it is in
  `~/.local/state/sudo-touch-setup/pam.d-sudo.before`. sudo still takes the
  password, so `sudo sed -i '/pam_u2f\.so/d' /etc/pam.d/sudo` takes the line
  out. If sudo itself broke, polkit, whose PAM stack is not sudo's, does it:

  ```bash
  pkexec sed -i '/pam_u2f\.so/d' /etc/pam.d/sudo
  ```

  If neither works, the recovery-mode root shell from the boot menu does.
- **pc or xmg19.** sudo still takes the password, so `sudo nixos-rebuild
  switch --rollback` undoes the last `nswitch`. For good: drop
  `../sudo-touch.nix` from that host's imports in `nix/nixos/<host>/configuration.nix`
  and `nswitch`.
- **The forwarded agent.** `systemctl --user stop ssh-sk-agent` on zephylux:
  ssh warns that it cannot forward the socket and connects anyway.
