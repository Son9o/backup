#!/bin/bash
##REQUIRES: Megatools installed(https://github.com/megous/megatools), mutt, awk
#all megatools calls are using ~/.megarc credentials
#For new MEGA account creation catch-all address must be set-up to the user that's running the script or otherwise permission to read spool given in email_drop variable.
#For ease of usage of all features best run as root
PATH=${PATH}:/usr/local/bin ## Adds location of megatools binaries to path
set -o nounset
set -o errexit
set_firstime_MEGA_password=This_is_your_s4fe_Password
E_MAIL=$USER@$HOSTNAME ##set e-mail to set backup log to
PASSWORD_MYSQL_ROOT=`awk 'NR == 1 {print $3}' /root/.mysqlrc` ## reads pass from /root/.mysqlrc in format "root = pass"
DATE=`date +%d-%m-%y-%H-%M`
backup_prefix=backup_
NAME=${backup_prefix}`hostname`_${DATE}.tar.gz
LOGFILE=$HOME/$NAME.log
BACKUP_TARGET=/ #What to back-up, default is whole filessytem
backup_file_location=$HOME/$NAME
#Just for account creation:
email_domain=$HOSTNAME
email_drop=/var/spool/mail/`whoami` #using spool for current user
##############
if [ -e $HOME/.megarc ] #######checking if there is .megarc file or creating a new one for new backups
then
	#echo ".mmegarc found using stored password"
	MEGA_password=`awk 'NR==3' $HOME/.megarc | awk '{print $3}'`
else
	echo "Creating a new MEGA Account and $HOME/.megarc"
	MEGA_password=$set_firstime_MEGA_password
	echo -e "[Login]\nUsername = ${backup_prefix}1000@${email_domain}\nPassword = $MEGA_password\n" > $HOME/.megarc
	$megaaccountnumber=1000
	MEGA_confirm_key=`megareg --name=${backup_prefix}$megaaccountnumber --email=${backup_prefix}$megaaccountnumber@${email_domain} --password=$MEGA_password --register --scripted | awk '{print $3}'`
    	sleep 1m 
    	MEGA_confirm_link=`tac $email_drop | grep ^http | grep -m1 confirm`
    	megareg --verify $MEGA_confirm_key $MEGA_confirm_link
	fi
###set logging to file
exec > $LOGFILE
exec 2>&1
###
##Starting regular script operation
echo "Initailised Logfile on $DATE" >> $LOGFILE
#dumping all mysqls using root account
mysqldump -u root -p${PASSWORD_MYSQL_ROOT} --events --all-databases | gzip > $HOME/backup_all_databases_$DATE.sql.gz
mysqldump -u root -p${PASSWORD_MYSQL_ROOT} pdns | gzip > $HOME/backup_pdns_database_$DATE.sql.gz
#Taking snapshot of filesystem excluding common runtime directories 
tar -cvpzf $backup_file_location --exclude=$backup_file_location --exclude=/proc --exclude=/sys --exclude=/mnt --exclude=/media --exclude=/run --exclude=/dev --exclude=/lost+found --exclude=/tmp --exclude=/home/transmission/Downloads --exclude=/var/lib/transmission/Downloads --exclude=$HOME/backup_filelist.log $BACKUP_TARGET > $HOME/backup_filelist.log
echo "Initailising Megatools operations:"
#checking whether there is enough free space for upload # whether file is bigger than 50 GB(size of free account) # and finally creating a new account if current one is too full
backup_file_size=`du -b $backup_file_location | awk '{print $1}'`
freespace=`megadf | grep Free | awk '{print $2}'`
if [ $freespace -gt $backup_file_size ]; then
    echo Uploading...
    echo "Output from upload:"
    /usr/local/bin/megaput $backup_file_location
elif [ $backup_file_size -gt 53687091200 ]; then
	echo This shit is too big for a free account
	exit 1
else
    echo not enough space on drive making new acc
    megaaccount=`awk 'NR==2' $HOME/.megarc | awk '{print $3}'` 
    megaaccountnumber=${megaaccount#${backup_prefix}}; megaaccountnumber=${megaaccountnumber%@${email_domain}}
    ((megaaccountnumber++))
    MEGA_confirm_key=`megareg --name=$backup_prefix$megaaccountnumber --email=$backup_prefix$megaaccountnumber@$email_domain --password=$MEGA_password --register --scripted | awk '{print $3}'`
    sleep 1m
    if [ `grep EEXIST ${LOGFILE} | wc -l` ]; then
		COUNTER_EEXIST=1
		((megaaccountnumber++))
		MEGA_confirm_key=`megareg --name=$backup_prefix$megaaccountnumber --email=$backup_prefix$megaaccountnumber@$email_domain --password=$MEGA_password --register --scripted | awk '{print $3}'`
		sleep 1m
		while [ `grep EEXIST ${LOGFILE} | wc -l` -gt $COUNTER_EEXIST ]
		do ##### I think it would be worth making a function for account creation since its the same thing across the board, seems to work though 
			((COUNTER_EEXIST++))
			((megaaccountnumber++))
			MEGA_confirm_key=`megareg --name=$backup_prefix$megaaccountnumber --email=$backup_prefix$megaaccountnumber@$email_domain --password=$MEGA_password --register --scripted | awk '{print $3}'`
			sleep 1m
    	done
	fi
    MEGA_confirm_link=`tac $email_drop | grep ^http | grep -m1 confirm`
    megareg --verify $MEGA_confirm_key $MEGA_confirm_link
    echo -e "[Login]\nUsername = ${backup_prefix}${megaaccountnumber}@${email_domain}\nPassword = $MEGA_password\n" > $HOME/.megarc
    /usr/local/bin/megaput $backup_file_location
fi
#Listing some usage statistics for email.
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
rm -f $HOME/backup_all_databases_$DATE.sql.gz
rm -f $backup_file_location
rm -f $HOME/backup_pdns_database_$DATE.sql.gz
rm -f $LOGFILE
