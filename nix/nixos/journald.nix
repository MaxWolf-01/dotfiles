# Small journal files, for fewer SSD writes. `setup ubuntu` writes the same two
# settings on the Ubuntu laptop.
#
# journald sizes each file's data hash table to SystemMaxFileSize (one bucket
# per 576 bytes of file, 2047 buckets at least), and every log line adds new
# values (its message, its timestamp) whose buckets sit on random pages of that
# table. Each dirtied page reaches the SSD whole, again every writeback cycle, so
# a bigger table means more pages written per line, not more history. At 1M the
# table is at its 2047-bucket floor: smaller files measure the same.
#
# journald also keeps at most SystemMaxFiles files (100 by default), whatever
# their size. With files this small that count bounds retention rather than
# SystemMaxUse, so it is raised to keep a few months. journalctl opens every
# file, about 0.2 ms each, and ignores any beyond 7168.
{
  services.journald.settings.Journal = {
    SystemMaxFileSize = "1M";
    SystemMaxFiles = 4000;
  };
}
