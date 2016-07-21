#!/bin/bash
#all megatools calls are using ~/.megarc credentials
PASSWORD_MYSQL=your_root_mysql_pass
DATE=`date +%d-%m-%y`
NAME=`hostname`_$DATE
LOGFILE=/root/backup_$NAME.log
exec > $LOGFILE
exec 2>&1
cd /
echo "Initailised Logfile on $DATE" >> $LOGFILE
mysqldump -u root -p$PASSWORD_MYSQL --events --all-databases | gzip > /root/all_databases_$DATE.sql.gz
tar -cvpzf $NAME.tar.gz --exclude=/$NAME.tar.gz --exclude=/proc --exclude=/sys --exclude=/mnt --exclude=/media --exclude=/run --exclude=/dev --exclude=/lost+found --exclude=/tmp --exclude=/home/son9o/steamcmd --exclude=/home/transmission/Downloads --exclude=/var/lib/transmission/Downloads --exclude=/root/backup_filelist.log / > /root/backup_filelist.log
echo "Initailising Megatools operations:"
echo "Output from upload:"
/usr/local/bin/megaput $NAME.tar.gz > 
echo "Disk space check:" 
/usr/local/bin/megadf --gb | tail -n3 >> /root/megastats.log
echo "File List:" 
/usr/local/bin/megals -hl | grep -i $NAME >> /root/megastats.log
echo "Login credentails used:" 
cat /root/.megarc >> /root/megastats.log
cat $LOGFILE | mailx -a /root/backup_filelist.log -s "backup-from $DATE" E-MAIL

#Clean-up
rm -f /root/all_databases_$DATE.sql.gz
rm -f /$NAME.tar.gz
