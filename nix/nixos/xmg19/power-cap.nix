# Caps the CPU's sustained package power (RAPL PL1) at 22W, so the fan stays
# low under worker load. The firmware's own limit is 40W on both PL1 and PL2.
#
# Measured under a 12-thread load (2026-10-24): at 40W the EC runs the fan at
# duty 100-120 (50 is its idle floor) and the package at ~69°C; at 22W the fan
# holds at 60 and the package at ~58°C, for about 75% of the throughput. PL2
# stays at 40W: the first ~10s of a load still run at 40W, until PL1's ~56s
# averaging window catches up.
#
# The firmware writes its 40W back once, about 32s after boot, from outside the
# OS (System Management Mode: a kernel trace of every MSR write saw nothing).
# So once udev has set 22W, the rule locks the register: bit 63 of
# MSR_PKG_POWER_LIMIT (0x610), after which the CPU ignores every write to it
# until the next reset, the firmware's included. The cost: PL1 and PL2 cannot
# change until a reboot, so this file is where a new value goes.
{ pkgs, ... }:

let
  lock = pkgs.writeShellScript "rapl-pl1-lock" ''
    ${pkgs.kmod}/bin/modprobe msr
    v=$(${pkgs.msr-tools}/bin/rdmsr -p 0 -0 0x610)
    ${pkgs.msr-tools}/bin/wrmsr -p 0 0x610 "$(printf '0x%x' $(( 0x$v | (1 << 63) )))"
  '';
in
{
  # One busy thread at the 4.5GHz turbo draws ~22W into a single core, which
  # runs it ~15°C hotter than the same 22W spread over all six, and the fan
  # follows the hottest core. Capped at 3.4GHz, one thread drew ~10W at 55°C
  # with the fan at its idle floor, for ~81% of its speed (2026-10-24, as
  # max_perf_pct 75). All-core load runs near 2.5GHz under PL1, below the cap.
  powerManagement.cpufreq.max = 3400000;

  hardware.cpu.x86.msr.enable = true;
  hardware.cpu.x86.msr.settings.allow-writes = "on";

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="intel-rapl:0", ATTR{constraint_0_power_limit_uw}="22000000", RUN+="${lock}"
  '';
}
