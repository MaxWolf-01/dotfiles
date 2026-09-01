return {
  -- Upstream derives the probe locations by walking up from the ngserver
  -- binary, which on nix lands in /nix/store. The nix wrapper already passes
  -- the right ones.
  cmd = { "ngserver", "--stdio" },
}
