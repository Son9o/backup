#!/bin/bash
##REQUIRES: Megatools installed(https://github.com/megous/megatools), mutt, awk
#all megatools calls are using ~/.megarc credentials
#For new MEGA account creation catch-all address must be set-up to the user that's running the script or otherwise permission to read spool given.
set -o nounset
set -o errexit
set_firstime_MEGA_password=This_is_your_s4fe_Password
E_MAIL=$USER@$HOSTNAME ##set e-mail to set backup log to
PASSWORD_MYSQL=your_root_mysql_pass
DATE=`date +%d-%m-%y-%H-%M`
backup_prefix=backup_
NAME=${backup_prefix}`hostname`_${DATE}.tar.gz
#LOGFILE=/root/backup_$NAME.log
LOGFILE=$HOME/$backup_prefix$NAME.log
BACKUP_TARGET=/root/testdir #What to back-up
backup_file_location=$HOME/$NAME
#Just for account creation:
email_domain=$HOSTNAME
#email_drop=/var/spool/mail/root #change for different user
email_drop=/var/spool/mail/`whoami`
if [ -e $HOME/.megarc ] 
then
	echo ".mmegarc found using stored password"
	MEGA_password=`awk 'NR==3' $HOME/.megarc | awk '{print $3}'`
else
	echo "Creating a new MEGA Account and $HOME/.megarc"
	MEGA_password=$set_firstime_MEGA_password
	echo -e "[Login]\nUsername = ${backup_prefix}1000@${email_domain}\nPassword = $MEGA_password\n" > $HOME/.megarc
	MEGA_confirm_key=`megareg --name=${backup_prefix}1000 --email=${backup_prefix}1000@${email_domain} --password=$MEGA_password --register --scripted | awk '{print $3}'`
    	sleep 1m 
    	MEGA_confirm_link=`tac $email_drop | grep ^http | grep -m1 confirm`
    	megareg --verify $MEGA_confirm_key $MEGA_confirm_link
	fi
exec > $LOGFILE
exec 2>&1
#cd /
echo "Initailised Logfile on $DATE" >> $LOGFILE
mysqldump -u root -p$PASSWORD_MYSQL --events --all-databases | gzip > $HOME/all_databases_$DATE.sql.gz
tar -cvpzf $backup_file_location --exclude=$backup_file_location --exclude=/proc --exclude=/sys --exclude=/mnt --exclude=/media --exclude=/run --exclude=/dev --exclude=/lost+found --exclude=/tmp --exclude=/home/transmission/Downloads --exclude=/var/lib/transmission/Downloads --exclude=$HOME/backup_filelist.log $BACKUP_TARGET > $HOME/backup_filelist.log
echo "Initailising Megatools operations:"
##
#checking whether there is enough free space for upload
backup_file_size=`du -b $backup_file_location | awk '{print $1}'`
freespace=`megadf | grep Free | awk '{print $2}'`
if [ $freespace -gt $backup_file_size ]; then
    echo Uploading...
    echo "Output from upload:"
    /usr/local/bin/megaput $backup_file_location
elif [ $backup_file_size -gt 53687091200 ]; then
	echo This shit is too big for a free account
else
    echo not enough space on drive makign new acc, #missing recursive call to upload and changing the megarc details
    #format used Username = backup_4digit_number@your_email_domain; requires a front digit eg.backup_1000@your_email_domain otherwise bash shortens it and string slicing will not work 
    megaaccount=`awk 'NR==2' $HOME/.megarc | awk '{print $3}'` 
    #megaaccountnumber=${megaaccount:7:4}
    megaaccountnumber=${megaaccount#${backup_prefix}}; megaaccountnumber=${megaaccountnumber%@${email_domain}}
    ((megaaccountnumber++))
    MEGA_confirm_key=`megareg --name=$backup_prefix$megaaccountnumber --email=$backup_prefix$megaaccountnumber@$email_domain --password=$MEGA_password --register --scripted | awk '{print $3}'`
    sleep 1m 
    MEGA_confirm_link=`tac $email_drop | grep ^http | grep -m1 confirm`
    megareg --verify $MEGA_confirm_key $MEGA_confirm_link
    echo -e "[Login]\nUsername = ${backup_prefix}${megaaccountnumber}@${email_domain}\nPassword = $MEGA_password\n" > $HOME/.megarc
    /usr/local/bin/megaput $backup_file_location
fi

echo "Disk space check:" 
/usr/local/bin/megadf --gb
echo "File List:"
/usr/local/bin/megals -ehl #| grep -i $NAME
echo "This backup:"
/usr/local/bin/megals -ehl | grep -i $NAME
echo "Login credentails used:" 
cat $HOME/.megarc
#sending execution log and filelist
email_subject="Backup of ${HOSTNAME} from ${DATE}"
cat $LOGFILE | mutt -a $HOME/backup_filelist.log -s "${email_subject}" -- $E_MAIL

#Clean-up
rm -f $HOME/all_databases_$DATE.sql.gz
rm -f $backup_file_location
rm -f $LOGFILE
