# agent-hl@xmg19: dispatch workers on the Helferline Claude account. Record in ./xmg19-agent-hl/.
import ../worker.nix {
  name = "agent-hl";
  # The work identity, as the includeIf on ~/work/ gives it on max's machines.
  identity = {
    name = "Maximilian Wolf";
    email = "maximilian.wolf@helferline.at";
  };
  record = ./xmg19-agent-hl/HOST.md;
  body = ./xmg19-worker-body.md;
}
