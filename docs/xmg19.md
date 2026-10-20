# xmg19

XMG Core laptop (hostname xmg19): i7-9750H, GTX 1660 Ti, NixOS
(`nix/nixos/xmg19/`).

## Ports

| Port | Wired to | Output |
|---|---|---|
| Internal panel | iGPU | `eDP-1` |
| HDMI and every DisplayPort output | dGPU | `HDMI-A-1`, `DP-1`, `DP-2` |

Read on 2026-10-20 from the outputs each GPU's DRM card lists, not by plugging
a monitor in. A monitor on any external port keeps the dGPU awake. Each GPU's
outputs, by PCI device rather than by card number:

    ls /sys/bus/pci/devices/0000:01:00.0/drm/card*/   # dGPU
    ls /sys/bus/pci/devices/0000:00:02.0/drm/card*/   # iGPU

## The discrete GPU

The NVIDIA driver is set up to cut the dGPU's power (D3cold) once nothing has
it open, and to power it back up when a program opens it, so a CUDA job needs
no step of its own. Not yet measured on xmg19: the setup is from 2026-10-20,
driver 595.104.02, kernel 6.18.54. The comments above `hardware.nvidia` and
`services.udev.extraRules` in `nix/nixos/xmg19/configuration.nix` say why it
takes the proprietary kernel module and a udev rule of our own.

Its state, read without waking it:

    cat /sys/bus/pci/devices/0000:01:00.0/power_state            # D3cold or D0
    cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status   # suspended or active

Anything that asks the driver wakes it: `nvidia-smi`, `nvtop`, CUDA, Vulkan.
The host recorder logs `runtime_status` as `gpu_pm` and asks `nvidia-smi` only
while the dGPU is already awake (`bin/host-recorder`'s header).
