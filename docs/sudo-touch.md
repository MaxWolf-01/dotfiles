# sudo by a YubiKey touch

sudo takes a touch of either YubiKey before it asks for the password: on
zephylux through pam_u2f, and on pc and xmg19, in an SSH session from zephylux,
through pam_rssh and a second ssh agent that holds only the YubiKeys' sk keys.
How each half works: `nix/home/sudo-touch.nix` (zephylux) and
`nix/nixos/sudo-touch.nix` (pc and xmg19).

The touch is `sufficient`, ahead of the password, never `required`. With no key
plugged in, no registered key, no forwarded agent, or no touch, sudo asks for
the password as it always did; a key plugged in but left untouched makes sudo
wait until the key gives up first.

The keys are the two YubiKeys, the keychain one and the backup. Register both at
every step that registers a key.

## Setting it up

Run these on zephylux, in `~/.dotfiles`, in this order. Each step that touches
sudo is safe to stop after: the password keeps working throughout.

1. **The laptop's keys for pam_u2f.** Plug in the keychain key, then:

   ```bash
   sudo apt-get install -y pamu2fcfg
   pamu2fcfg -u max > nix/yubikey/u2f_keys      # touch the keychain key when it blinks
   ```

   Swap in the backup key, then append it to the same line:

   ```bash
   pamu2fcfg -n >> nix/yubikey/u2f_keys         # touch the backup key
   cat nix/yubikey/u2f_keys                      # one line: max:<key>:<key>
   ```

   The file is public data: a credential id and a public key per YubiKey. It is
   bound to this machine's hostname (pam_u2f's default origin is
   `pam://<hostname>`), so a reinstall under another hostname registers again.

2. **The two sk keys**, one per YubiKey, each touched once as it is made. Press
   Enter at the passphrase prompt: the file is a handle, useless without the key
   it was made on.

   ```bash
   ssh-keygen -t ed25519-sk -f ~/.ssh/id_ed25519_sk_keychain -C "sudo-touch keychain"   # keychain key
   ssh-keygen -t ed25519-sk -f ~/.ssh/id_ed25519_sk_backup -C "sudo-touch backup"       # backup key
   cat ~/.ssh/id_ed25519_sk_keychain.pub ~/.ssh/id_ed25519_sk_backup.pub >> nix/yubikey/sudo-sk-keys.pub
   ```

   Keep a copy of both handle files (with their `.pub`) in `secrets/`, beside
   `id_ed25519`: a reinstall that has them back needs none of this step again.
   Without them, make new ones and replace the lines in `sudo-sk-keys.pub`.

3. **Commit and switch.** `git add nix/yubikey/u2f_keys nix/yubikey/sudo-sk-keys.pub`,
   commit, then `hmswitch`. Check the agent holds the two sk keys and nothing
   else:

   ```bash
   systemctl --user status ssh-sk-agent
   SSH_AUTH_SOCK=/run/user/$(id -u)/ssh-sk-agent ssh-add -L    # two sk-ssh-ed25519@openssh.com lines
   ```

4. **zephylux's sudo.** Open a root shell in a second terminal first
   (`sudo -s`) and leave it open until the test below passes. Then:

   ```bash
   ./setup sudo_touch      # installs libpam-u2f, adds the line to /etc/pam.d/sudo
   ```

   Test, in a new terminal: `sudo -k; sudo true` says "Please touch the
   device."; a touch of either key lets it through. Unplug the key and try
   again: the password prompt comes as before.

5. **pc.** Push the commit, then on pc open a root shell in a second session
   (`sudo -s`) and leave it open; in the first, `git -C ~/.dotfiles pull` and
   `nswitch`. From zephylux, open a **new** `ssh pc` (an agent is forwarded when
   the connection opens) and:

   ```bash
   ssh-add -L          # on pc: the two sk keys, and id_ed25519 not among them
   sudo -k; sudo true  # the key blinks; touch it
   ```

   While it blinks, `ls /run/user/$(id -u)/prompt-waits/` on zephylux holds a
   waiting prompt naming pc, which the prompt notifier shows once it runs.

   With the key unplugged, the same `sudo` asks for the password.

6. **xmg19.** Step 5 again, on xmg19 (`ssh xmg19`).

## When it does not work

The password still works, so sudo is not locked; the touch is just not taken.

- **No blink at all on pc or xmg19.** `echo $SSH_AUTH_SOCK` and `ssh-add -L` in
  that session: an empty answer means no agent was forwarded. The session was
  opened before step 3, or inside a tmux started by an older session, whose
  `SSH_AUTH_SOCK` points at a connection that is gone. Open a new `ssh pc`.
- **A blink, a touch, and still the password prompt.** pam_rssh refused the
  signature. `journalctl -b _COMM=sudo` on that host says why; for more, set
  `security.pam.rssh.settings.loglevel = "debug";` in `nix/nixos/sudo-touch.nix`
  and `nswitch`. `tests/sudo-touch/agent-to-pam.test` drives the same PAM line
  with a software security key, which tells a problem with the setup from one
  with the YubiKey.
- **On zephylux, no "Please touch the device."** `ls -l ~/.config/Yubico/u2f_keys`
  (missing: step 1 or 3), then add `debug` to the line in `/etc/pam.d/sudo`.

## Backing out

- **zephylux.** From the root shell kept open in step 4, or, without one,
  through polkit, whose PAM stack is not sudo's:

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
