# Incremental backup script based on rsync and hard links for *nix systems

Author: Attila Kerekes

It was designed the make every working day evening one backup and shut down
the server for that day.
Cron should run this script after office closing hours.

## What it should do:

 - Mount backup drive
 - Make some incremental backup
 - Log everything
 - Send report on email
 - Shutdown the system if
  - no files are locked in samba
  - nobody is logged in
  - (nobody is working anymore)