#!/bin/bash
DATE=`date +%d-%m-%y`
NAME=`hostname`_$DATE
cd /
mysqldump -u root -p$PASSWORD_MYSQL --events --all-databases | gzip > /root/all_databases_$DATE.sql.gz
tar -cvpzf $NAME.tar.gz --exclude=/$NAME.tar.gz --exclude=/proc --exclude=/sys --exclude=/mnt --exclude=/media --exclude=/run --exclude=/dev --exclude=/lost+found --exclude=/tmp --exclude=/home/son9o/steamcmd --exclude=/home/transmission/Downloads --exclude=/var/lib/transmission/Downloads --exclude=/root/backup.log / > /root/backup.log
/usr/local/bin/megaput $NAME.tar.gz
/usr/local/bin/megadf --gb | tail -n3 > /root/megastats.log
/usr/local/bin/megals -hl | grep -i $NAME >> /root/megastats.log
cat /root/.megarc >> /root/megastats.log
cat /root/megastats.log | mailx -a /root/backup.log -s "backup-from $DATE" E-MAIL

#Clean-up
rm /root/all_databases_$DATE.sql.gz
rm /$NAME.tar.gz
