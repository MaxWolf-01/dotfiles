# agent-hl@pc: dispatch workers on the Helferline Claude account. Record in ./pc-agent-hl/, entry in ../machines.nix.
import ../worker.nix {
  name = "agent-hl";
  # One identity everywhere, work repos included: max's noreply address.
  identity = {
    name = "Maximilian Wolf";
    email = "69987866+MaxWolf-01@users.noreply.github.com";
  };
}
