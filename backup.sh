#!/bin/bash
##REQUIRES: Megatools installed(https://github.com/megous/megatools), mutt, awk
#all megatools calls are using ~/.megarc credentials
E_MAIL=your_email_address
PASSWORD_MYSQL=your_root_mysql_pass
DATE=`date +%d-%m-%y-%H-%M`
NAME=`hostname`_$DATE
LOGFILE=/root/backup_$NAME.log
BACKUP_TARGET=/root/testdir #What to back-up
#Just for account creation:
email_domain=your_email_domain
email_drop=/var/spool/mail/root #change for different user
MEGA_password=`awk 'NR==3' /root/.megarc | awk '{print $3}'`
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
    echo not enough space on drive makign new acc, #missing recursive call to upload and changing the megarc details
    #format used Username = backup_4digit_number@your_email_domain; requires a front digit eg.backup_1000@your_email_domain otherwise bash shortens it and string slicing will not work 
    megaaccount=`awk 'NR==2' /root/.megarc | awk '{print $3}'` 
    megaaccountnumber=${megaaccount:7:4}
    ((megaaccountnumber++))
    MEGA_confirm_key=`megareg --name=backup_$megaaccountnumber --email=backup_$megaaccountnumber@$email_domain --password==$MEGA_password --register --scripted | awk '{print $3}'
    sleep 1m 
    #Below line greps in root mailfolder for mega verification link, this will probably be best adjusted for some other user
    MEGA_confirm_link=`tac $email_drop | grep ^http | grep -m1 confirm`
    megareg --verify $MEGA_confirm_key $MEGA_confirm_link

fi

echo "Disk space check:" 
/usr/local/bin/megadf --gb
echo "File List:"
/usr/local/bin/megals -ehl #| grep -i $NAME
echo "This backup:"
/usr/local/bin/megals -ehl | grep -i $NAME
echo "Login credentails used:" 
cat /root/.megarc
#sending execution log and filelist
cat $LOGFILE | mutt -a /root/backup_filelist.log -s "$SUBJECT" -- $E_MAIL

#Clean-up
rm -f /root/all_databases_$DATE.sql.gz
rm -f /$NAME.tar.gz
rm -f $LOGFILE
