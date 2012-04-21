#!/bin/bash
##
# Incremental backup script based on rsync
# Author: Attila Kerekes
#
# It was designed the make every working day evening one backup and shut down
# the server for that day.
# Cron should run this script after office closing hours.
#
# What it should do:
#   - Mount backup drive
#   - Make some incremental backup
#   - Log everything
#   - Send report on email
#   - Shutdown the system if
#      - no files are locked in samba
#      - nobody is logged in
#      - (nobody is working anymore)
#

##
# Options

# Route to working directorys
BUSRC=/mnt/raid-live/work

# Route to backup
BUDIR=/mnt/raid-backup/work-backup

# Device to mount
MOUNT_DEVICE=/dev/sdc1

# Place to mount your device
MOUNT_LOCATION=/mnt/raid-backup

# Reporting email address
TOEMAIL="your@email.com"
FROMMAIL="admin@myhost.com"


##
# executable files

DATE=/bin/date
RSYNC=/usr/bin/rsync
CP=/bin/cp
TOUCH=/bin/touch
MOUNT=/bin/mount
ECHO=/bin/echo
CAT=/bin/cat
RM=/bin/rm
SENDMAIL=/usr/sbin/sendmail
GREP=/bin/grep
SMBSTATUS=/usr/bin/smbstatus
SHUTDOWN=/sbin/shutdown
WHO=/usr/bin/who
CUT=/usr/bin/cut

# Date format
BUDATE=`$DATE +%Y-%m-%d_%H-%M`

# Directory for backup archives
BUDEST=$BUDIR/old/backup-$BUDATE

# Directory for log files
LOGLOCATION=$BUDIR/log

# Name of logfiles
LOGFILE=$LOGLOCATION/backup-$BUDATE.log

# rsync options
OPTS="--delete --force --ignore-errors --backup --backup-dir=$BUDEST -azh --stats "

# Email
SUBJECT="[host] - Daily backup - $BUDATE"
EMAILTMP="/tmp/tmpfil_456"$RANDOM

##
# Backup function
#
function do_backup {

	# Remount the backup device to rw
	$MOUNT -o remount,rw $MOUNT_DEVICE $MOUNT_LOCATION;

	if (( $? )); then
		$DATE >> $LOGFILE;
		$ECHO "ERROR: could not remount $MOUNT_LOCATION readwrite" >> $LOGFILE;
		return;
	fi;

	# Log file first line
	$DATE > $LOGFILE;

	# run rsync, output to logfile
	$RSYNC $OPTS $BUSRC $BUDIR/current &>> $LOGFILE;

	# update the date on "current" directory
	$TOUCH $BUDIR/current;

	# Create hard links for the "current" directory
	$CP -al $BUDIR/current/* $BUDEST/;

    # Finish logfile
    $ECHO "FINISHED" >> $LOGFILE;
    $DATE >> $LOGFILE;
}

##
# Append to file helper function
#
function fappend {
    echo "$2">>$1;
}

##
# Email sender function
#
function send_email {
	$RM -f $EMAILTMP

	fappend $EMAILTMP "From: $FROMMAIL";
	fappend $EMAILTMP "To: $TOEMAIL";
	fappend $EMAILTMP "Reply-To: $FROMMAIL";
	fappend $EMAILTMP "Subject: $SUBJECT";
	fappend $EMAILTMP "";
	$CAT $LOGFILE >> $EMAILTMP
	fappend $EMAILTMP "";
	fappend $EMAILTMP "";
	$CAT $EMAILTMP | $SENDMAIL -t;
	$RM $EMAILTMP;
}

##
# Shut down function
#
function do_shutodown {

    # Check if someone is still working :)
	STATUS=`$SMBSTATUS | $GREP "No locked files"`;
	LOGINSTATUS=`$WHO -q | $GREP users | $CUT -d '=' -f2`;

	if [ "$STATUS" == "No locked files"] && [ "$LOGINSTATUS" -gt 0 ]; then
	    # Nobody online, nobody working, shutdown
		$SHUTDOWN -h +5
		return;
	fi;

    # Somebody still working, log it
	$ECHO "ERROR: could not shut down the system!" >> $LOGFILE;
	$SMBSTATUS &>> $LOGFILE;
	$WHO -q &>> $LOGFILE;

    # Remount backup device read only
    $MOUNT -o remount,ro $MOUNT_DEVICE $MOUNT_LOCATION ;
    if (( $? )); then
        $DATE >> $LOGFILE;
        $ECHO "ERROR: could not remount $MOUNT_LOCATION readonly" >> $LOGFILE;
    fi;
}

do_backup
send_email
do_shutodown

exit 0

