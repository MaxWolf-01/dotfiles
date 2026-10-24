# Caps the CPU's sustained package power (RAPL PL1) at 22W, so the fan stays
# low under worker load. The firmware's own limit is 40W on both PL1 and PL2.
#
# Measured under a 12-thread load (2026-10-24): at 40W the EC runs the fan at
# duty 100-120 (50 is its idle floor) and the package at ~69°C; at 22W the fan
# holds at 60 and the package at ~58°C, for about 75% of the throughput. One
# thread at full turbo draws ~23W, so single-thread speed is barely touched. PL2
# stays at 40W: the first ~30s of a load still run at 40W, until PL1's ~56s
# averaging window catches up.
#
# The value resets whenever the RAPL device appears (boot, module reload), so
# a udev rule sets it on each add. The value read back proves nothing on its
# own; the package power drawn under load does.
{ ... }:

{
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="intel-rapl:0", ATTR{constraint_0_power_limit_uw}="22000000"
  '';
}
