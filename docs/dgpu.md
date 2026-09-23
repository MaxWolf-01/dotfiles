# The discrete GPU

On the Ubuntu laptop (zephylux, GU603ZW, RTX 3070 Ti) the NVIDIA driver
powers the dGPU down to D3cold whenever nothing uses it, and `bin/dgpu` keeps
it that way on battery by locking its device files. `dgpu --help` has the
commands and the terms; `./setup dgpu_runtime_pm` installs it.

`watch dgpu status` is the instrument: card, power state, lock, power source.

## What holds

Measured on 2026-09-23, driver 580.178, kernel 7.0.0-34:

- Idle on AC, unlocked: D3cold. Idle on battery, locked: D3cold. The card
  goes to sleep within seconds of its last user exiting, on either.
- gnome-shell holds handles on the card (`nvidia-smi` lists it with 3 MiB)
  and that does not keep it awake.
- Unplugging the charger locks and the card sleeps within seconds; replugging
  unlocks. Resume from hibernate: D3cold, locked, the unit ran on the wake.
- A locked card refuses `nvidia-smi` ("Insufficient Permissions") and every
  other open made as the user.
- `sudo nvidia-smi` still reads the card, since root ignores permission bits,
  and wakes it for as long as it runs; it no longer rewrites the device files
  to 0666 (`NVreg_ModifyDeviceFiles=0`, set by the setup step).

## What wakes it

Anything that opens the device files while they are unlocked, for as long as
it holds them:

- NVML readers: `nvidia-smi`, btop's GPU panel (drop `gpu0` from
  `shown_boxes` to keep btop from waking it), `nvtop`.
- CUDA, a Vulkan or EGL app that picks the dGPU, GNOME's "Launch using
  Graphics Card".
- A monitor on HDMI, which is wired to the dGPU, for as long as it is
  connected. Plugging it into a running session crashes gnome-shell, locked
  or not, and gdm restarts the session with the monitor working; a session
  that starts with the cable in works from the start. Save your work before
  plugging in or out. The bug: `agent/tickets/hdmi-hotplug-crashes-gnome-shell.md`.

Who holds it right now:

    for p in /proc/[0-9]*; do ls -l $p/fd 2>/dev/null | grep -E '/dev/(nvidia|dri/renderD129)' | sed "s|^|$(cat $p/comm) |"; done | awk '{print $1, $NF}' | sort | uniq -c

The driver's own view: `cat /proc/driver/nvidia/gpus/0000:01:00.0/power`.
The unit's runs: `journalctl -b -u dgpu-auto`. History: thermal-log's
`dgpu_port` column (D3cold or D0 every 5 s).

## Traps

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
- **`reboot -h 0`** is not a thing on systemd; `reboot`.
