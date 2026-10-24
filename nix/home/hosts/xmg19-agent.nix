# agent@xmg19: dispatch workers on the personal Claude account. Record in ./xmg19-agent/.
import ../worker.nix {
  name = "agent";
  # Attributable in `git log` as the bot account, not as max.
  identity = {
    name = "MaxWolf-01-clanker";
    email = "MaxWolf-01-clanker@users.noreply.github.com";
  };
  record = ./xmg19-agent/HOST.md;
  body = ./xmg19-worker-body.md;
}
