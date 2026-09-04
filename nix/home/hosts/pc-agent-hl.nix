# agent-hl@pc: dispatch workers on the Helferline Claude account. Record in ./pc-agent-hl/.
import ../worker.nix {
  name = "agent-hl";
  # The work identity, as the includeIf on ~/work/ gives it on max's machines.
  identity = {
    name = "Maximilian Wolf";
    email = "maximilian.wolf@helferline.at";
  };
  record = ./pc-agent-hl/HOST.md;
}
