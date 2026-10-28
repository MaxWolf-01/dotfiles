# zephyrus

ASUS ROG Zephyrus M16 GU603ZW (hostname zephylux): i9-12900H, RTX 3070 Ti
Laptop GPU, Ubuntu with standalone Home Manager.

## Ports

| Port | Wired to | Output |
|---|---|---|
| Thunderbolt 4 (USB-C, bolt icon) | iGPU | `DP-1`, `DP-2`; a dock's monitors also on `DP-4` to `DP-6` |
| USB-C 3.2 (DP and bolt icons) | dGPU | `DP-3`; a dock's monitors on the outputs it opens under it (`DP-4`, `DP-5`) |
| HDMI | dGPU | `HDMI-A-1` |

Measured on 2026-09-28 by which card reads the monitor's EDID; the dGPU's
power state does not reroute a port. A monitor on a dGPU port keeps the dGPU in
D0. Two monitors on the iGPU need both on the Thunderbolt port, through an MST
hub or a Thunderbolt dock. The ThinkPad Thunderbolt 4 Dock there drives the LG
ultrawide at 3440x1440@100 and the Arzopa at 2560x1600@60 (2026-10-01).

The dock belongs on the Thunderbolt port. On the USB-C 3.2 port it works as a
USB-C dock, and its monitors land on the dGPU: the dGPU stays awake, monitors
are slow to come up, and pages and images render slowly, since mutter's shared
iGPU/dGPU path fails here ("No EGL display") and it copies every frame
instead (2026-10-06). `boltctl list` says which port the dock is on: on the
Thunderbolt port it reads `authorized`, on the other `disconnected`.

The kernel names an output `cardN-<output>`, and N changes between boots: the
dGPU was `card2` on 2026-09-28 and `card1` on 2026-09-29. `dgpu status` lists
this boot's names for the dGPU's outputs and which have a monitor on them.
Every GPU's outputs:

    for c in /sys/class/drm/card*-*; do echo "${c##*/} $(cat $c/status)"; done

## Heat

The CPU and dGPU share heat pipes. `asus-power-cap` caps the CPU; nothing caps
the dGPU. `nvidia-smi -pl` is unsupported, and with `nv_temp_target` at 75 °C,
`nv_dynamic_boost` at 5 W and clocks locked to 900 MHz (`nvidia-smi -lgc`), a
CUDA load still took it from 66 °C to 86 °C in 5 s at 70-80 W.

The dGPU cuts the power at 98 °C (`nvidia-smi -q -d TEMPERATURE`): the screen
goes black at once and the journal just stops. That happened three times
between 2026-09-20 and 2026-09-26, each time during a CUDA job. GPU compute
belongs on pc or a pod.

## The discrete GPU

The NVIDIA driver powers the dGPU down to D3cold whenever nothing uses it, and
`bin/dgpu` keeps it that way by locking its device files, on AC and on
battery alike, unless a monitor is on one of the dGPU's ports. The dock at the
desk drives its monitors through the Thunderbolt port, which is the iGPU's, so
docked the dGPU stays locked. `dgpu --help` has the commands, the terms and
what runs it when; `./setup dgpu_runtime_pm` installs it.

The lock evicts nothing. A program that opened the dGPU while it was unlocked
keeps it awake until it exits; logging out and in again clears the session's,
and from the next boot the lock is in place before gdm starts. A `dgpu unlock`
typed by hand stands until the next hotplug on the dGPU, driver load, wake
or boot.

`watch dgpu status` is the instrument: card, power state, lock, the dGPU's
outputs, power source.

### What holds

Measured on 2026-09-23, driver 580.178, kernel 7.0.0-34:

- Idle on AC, unlocked: D3cold. Idle on battery, locked: D3cold. The card
  goes to sleep within seconds of its last user exiting, on either.
- gnome-shell holds handles on the card (`nvidia-smi` lists it with 3 MiB)
  and that does not keep it awake, unless that login has driven a monitor on
  a dGPU port. Then gnome-shell keeps the card in D0 until logout, after the
  monitor is gone (a login of 2026-09-30 that began with a monitor on `DP-3`
  held it until 2026-10-16; the login after the next boot let it sleep).
- At login, logind gives the user an ACL entry on the render node
  (`user:max:rw-`), which the lock does not clear, so `dgpu status` reads
  "unlocked" on a locked card. Opening the render node and querying its driver
  leaves the card in D3cold (2026-10-16); `/dev/nvidia*` carry no ACL and stay
  locked. `agent/tickets/dgpu-lock-survives-logind-acl.md`.
- Resume from hibernate: D3cold, locked.
- A locked card refuses `nvidia-smi` ("Insufficient Permissions") and every
  other open made as the user.
- `sudo nvidia-smi` still reads the card, since root ignores permission bits,
  and wakes it for as long as it runs; it no longer rewrites the device files
  to 0666 (`NVreg_ModifyDeviceFiles=0`, set by the setup step).

### What wakes it

Anything that opens the device files while they are unlocked, for as long as
it holds them:

- NVML readers: `nvidia-smi`, btop's GPU panel (drop `gpu0` from
  `shown_boxes` to keep btop from waking it), `nvtop`.
- CUDA, a Vulkan or EGL app that picks the dGPU, GNOME's "Launch using
  Graphics Card".
- A monitor on a dGPU port (see Ports), for as long as it is connected.
- `dgpu`'s probe of the dGPU's outputs, on a change of its card and after a
  wake, where gnome-shell's own probe follows and would wake it anyway.

The NVIDIA kernel driver also wakes it by itself, for about 20 s, on two
platform events, locked or not:

- A power-profile switch (the fan key cycles quiet, balanced, performance,
  one wake per step). The firmware notifies `\_SB.NPCF`, and the driver's
  NVPCF handler takes a runtime-PM reference to pass the event on.
- A charger plug or unplug, through the driver's power-source handler.

No module parameter guards either handler (580.178.04 and 615.71.09 alike),
and `nvidia-powerd` plays no part: with it stopped, a profile switch still
woke the card in 0.6 s (2026-10-28). A drop in battery percentage does not
wake it on this model. NVIDIA's fix for the NVPCF wake is PR #1299 on
open-gpu-kernel-modules (issue #1300), open as of 2026-10-28; it leaves the
charger wake alone.

Who holds it right now:

    r=$(readlink -f /dev/dri/by-path/pci-0000:01:00.0-render)
    for p in /proc/[0-9]*; do ls -l $p/fd 2>/dev/null | grep -E "/dev/nvidia|$r" | sed "s|^|$(cat $p/comm) |"; done | awk '{print $1, $NF}' | sort | uniq -c

The driver's own view: `cat /proc/driver/nvidia/gpus/0000:01:00.0/power`.
`dgpu`'s runs at boot and on a driver load: `journalctl -b -u dgpu-auto`; after
a wake: `journalctl -b -u dgpu-resume`, and the sleep hook's unlock under
`journalctl -b -u 'systemd-*suspend*' -u 'systemd-*hibernate*'`.
History: the host recorder's `dgpu_port` column (D3cold or D0 every 5 s).

### Traps

- **A monitor on a dGPU port with the card locked.** gnome-shell draws that
  monitor through the dGPU; its next frame fails with `Failed to create EGL
  image from buffer object for secondary GPU` and the session hangs until a
  hard reset, which an unlock afterwards does not undo. On 2026-09-29 a resume
  from hibernate on battery did this. `dgpu` never locks while a dGPU output
  reads `connected` or `unknown`. An output reads what the driver's last probe
  found, and after a hotplug or a wake nvidia-drm leaves that probe to
  gnome-shell, so a monitor just plugged in still reads `disconnected`. `dgpu`
  therefore probes the outputs itself before any decision that could lock: on
  a change of the dGPU's card, from udev before the event reaches gnome-shell;
  after a wake, from the `dgpu-resume` unit once the NVIDIA driver has
  resumed, with the dGPU unlocked by a sleep hook before user processes are
  thawed. At boot and on a driver load it probes only a dGPU in D0, since in
  D3cold the dGPU drives no monitor; during a wake, that decision waits for
  `dgpu-resume`. It cannot stop a `dgpu lock` typed by hand under a monitor,
  nor an installed copy that differs from `bin/dgpu` (`dgpu status` says so;
  `dgpu install` replaces it).
- **HDMI hot-plug.** Plugging HDMI into a running session crashes gnome-shell,
  locked or not, and gdm restarts the session with the monitor working; a
  session that starts with the cable in works from the start. Save your work
  before plugging in or out. The bug:
  `agent/tickets/hdmi-hotplug-crashes-gnome-shell.md`.
- **A kernel upgrade without its NVIDIA modules.** Ubuntu phases updates, and
  `apt upgrade` can install `linux-image-X` while holding back
  `linux-modules-nvidia-580-open-X`. Booting that kernel leaves the card on
  the bus with no driver, which is the one state nothing can power down;
  `dgpu status` then says "no dGPU with a driver bound". Before rebooting into
  a new kernel: `ls /lib/modules/<version>/kernel/nvidia-580-open/nvidia.ko`,
  and if it is missing, `sudo apt install linux-modules-nvidia-580-open-generic`.
- **The firmware switch (`dgpu_disable`, Armoury Crate's Eco mode).** Not
  used, and not to be used: on this BIOS both directions run a method
  (`AGOF`/`AGON`) that waits without bound for the card's PCIe link, and Linux
  has powered the root port down by then, so each direction times out after
  30 s. A failed switch-on leaves a "dGPU off" flag in CMOS that can hide the
  card at the next boot. supergfxctl's Integrated mode is that switch; it was
  removed for this reason.
- **A wake that kills the card.** On 2026-09-29 a monitor unplug made the
  driver wake the card, its firmware never came back (Xid 119, then 154), and
  the next hibernate hung in `nvidia-sleep.sh` with the lid shut until the
  power cut out. On 2026-10-28 a profile switch woke it, the GSP firmware
  crashed (Xid 120) and failed to boot again (Xid 154), and three minutes
  later the laptop powered off hard, the journal stopping mid-line; likely
  the dGPU's 98 °C cutoff, unmeasured. Reported on open-gpu-kernel-modules
  issue #1284. `dgpu-wedge-watch` (`nix/home/timers.nix`) tells max to
  reboot when the kernel logs it; only a reboot recovers the card. The closed
  kernel module without GSP firmware would avoid the crash, but the open
  module is where NVIDIA is heading, so it is not used.
- **The dock's monitors black after a resume.** On 2026-10-06 the
  thunderbolt driver tore down both DisplayPort tunnels right after a resume
  (`(DP): not active, tearing down` in `journalctl -k`), and the dock's
  monitors stayed black until it was replugged. Replug it into the Thunderbolt
  port; that night it went into the USB-C 3.2 port instead (see Ports).
- **`reboot -h 0`** is not a thing on systemd; `reboot`.
