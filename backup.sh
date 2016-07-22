#!/bin/bash
#all megatools calls are using ~/.megarc credentials
E_MAIL=your_email_address
PASSWORD_MYSQL=your_root_mysql_pass
DATE=`date +%d-%m-%y-%H-%M`
NAME=`hostname`_$DATE
LOGFILE=/root/backup_$NAME.log
BACKUP_TARGET=/root/testdir #What to back-up
exec > $LOGFILE
exec 2>&1
cd /
echo "Initailised Logfile on $DATE" >> $LOGFILE
mysqldump -u root -p$PASSWORD_MYSQL --events --all-databases | gzip > /root/all_databases_$DATE.sql.gz
tar -cvpzf $NAME.tar.gz --exclude=/$NAME.tar.gz --exclude=/proc --exclude=/sys --exclude=/mnt --exclude=/media --exclude=/run --exclude=/dev --exclude=/lost+found --exclude=/tmp --exclude=/home/son9o/steamcmd --exclude=/home/transmission/Downloads --exclude=/var/lib/transmission/Downloads --exclude=/root/backup_filelist.log $BACKUP_TARGET > /root/backup_filelist.log
echo "Initailising Megatools operations:"
##
file=/$NAME.tar.gz
#checking whether there is enough free space for upload
backup_file_size=`du -b /$NAME.tar.gz | awk '{print $1}'`
freespace=`megadf | grep Free | awk '{print $2}'`
if [ $freespace -gt $backup_file_size ]; then
    echo Uploading...
	echo "Output from upload:"
	/usr/local/bin/megaput $NAME.tar.gz
elif [ $backup_file_size -gt 53687091200 ]; then
	echo This shit is too big for a free account
	
else
    echo not enough space on drive makign new acc, broken for now

fi

echo "Disk space check:" 
/usr/local/bin/megadf --gb
echo "File List:" 
/usr/local/bin/megals -hl #| grep -i $NAME
echo "Login credentails used:" 
cat /root/.megarc
#sending execution log and filelist
cat $LOGFILE | mutt -a /root/backup_filelist.log -s "$SUBJECT" -- $E_MAIL

#Clean-up
rm -f /root/all_databases_$DATE.sql.gz
rm -f /$NAME.tar.gz
rm -f $LOGFILE
