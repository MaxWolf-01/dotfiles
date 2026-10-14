# Small journal files cut journald's SSD writes: each file's hash table is sized
# to SystemMaxFileSize, and every log line dirties random pages of it. 1M is the
# table's minimum. journald keeps at most SystemMaxFiles files, so that count,
# not SystemMaxUse, is what bounds history. `setup ubuntu` sets the same on the laptop.
{
  services.journald.settings.Journal = {
    SystemMaxFileSize = "1M";
    SystemMaxFiles = 2000;
  };
}
