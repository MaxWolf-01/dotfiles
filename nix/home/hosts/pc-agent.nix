# agent@pc: dispatch workers on the personal Claude account. Record in ./pc-agent/.
import ../worker.nix {
  name = "agent";
  # Attributable in `git log` as the bot account, not as max.
  identity = {
    name = "MaxWolf-01-clanker";
    email = "MaxWolf-01-clanker@users.noreply.github.com";
  };
  record = ./pc-agent/HOST.md;
}
