set -x
export ORAENV_ASK=NO
export ORACLE_SID=$1
BACKUP_PATH=/backuporacle/${ORACLE_SID}
CTLFILEBCK=`ls /backuporacle/${ORACLE_SID}/*_CTRL_*`
LOG=/backuporacle/${ORACLE_SID}/restore_${ORACLE_SID}_`date +%y%d%m_%H%m`.log
ORADATA=/u02/app/oracle/oradata/${ORACLE_SID}/${ORACLE_SID}

if [ $# -ne 1 ]; then
  printf 'database SID is missing'
  exit 1
fi

#1 add db into oratab
printf "start: "`date +%y%d%m_%H%m`"$0 \n" > $LOG
printf "PID of this script : $$ \n" >> $LOG
printf "***********\ncheck if database is referenced in /etc/oratab : ">> $LOG
if [ `grep -c ${ORACLE_SID} /etc/oratab` -ne 1 ]; then
  printf 'database not configured in /etc/oratab \n' >> $LOG
else
  . oraenv
  printf 'true\n***********\n' >> $LOG
fi

DBID=`grep 'DBID' ${ORACLE_SID}.odacli| awk '{ print $2 }'`

printf '***********\ncreating system folders : ' >> $LOG
mkdir -p /u02/app/oracle/oradata/${ORACLE_SID}/${ORACLE_SID}
mkdir -p /u03/app/oracle/fast_recovery_area/${ORACLE_SID}/${ORACLE_SID}/arch
mkdir -p /u03/app/oracle/redo/${ORACLE_SID}
mkdir -p /u04/app/oracle/redo/${ORACLE_SID}
mkdir -p /u01/app/oracle/admin/${ORACLE_SID}/adump

printf 'done\n***********\n' >> $LOG

printf '***********\ntrying to start the database and restore the control file : \n' >> $LOG
printf "STARTUP NOMOUNT;
RESTORE CONTROLFILE FROM '${CTLFILEBCK}';
ALTER DATABASE MOUNT;\n" > restore${ORACLE_SID}_to_mount.rman

rman target / cmdfile='restore'${ORACLE_SID}'_to_mount.rman' > restore${ORACLE_SID}_to_mount.log
cat restore${ORACLE_SID}_to_mount.log >> $LOG

if [ $? -ne 0 ]; then
  printf 'Restore Failed \n***********\n' >> $LOG
  exit 1
fi

cat /dev/null > restore${ORACLE_SID}_catalog.rman
printf '***********\ncatalog backup pieces from ${BACKUP_PATH} \n' >> $LOG
for bckpiece in `ls $BACKUP_PATH/*MANU_DB_FULL*.bkp`
do
  printf "CATALOG DEVICE TYPE 'DISK' BACKUPPIECE '${bckpiece}';\n" >> restore${ORACLE_SID}_catalog.rman
done

printf '***********\ncatalog backup pieces from ${BACKUP_PATH} \n' >> $LOG
for bckpiece in `ls $BACKUP_PATH/*MANU_LOGS_*.bkp`
do
  printf "CATALOG DEVICE TYPE 'DISK' BACKUPPIECE '${bckpiece}';\n" >> restore${ORACLE_SID}_catalog.rman
  printf "crosscheck backup;" >> restore${ORACLE_SID}_catalog.rman
  printf "delete noprompt expired backup;" >> restore${ORACLE_SID}_catalog.rma
done

rman target / cmdfile='restore'${ORACLE_SID}'_catalog.rman' > restore${ORACLE_SID}_to_catalog.log

if [ $? -ne 0 ]; then
  printf 'cataloging of backup pieces failed\n' >> $LOG
  exit 1
fi

printf 'run {
CONFIGURE DEVICE TYPE DISK PARALLELISM 4;
SET NEWNAME FOR DATABASE TO NEW;
RESTORE DATABASE;
SWITCH DATAFILE ALL;
}' > restore${ORACLE_SID}_database.rman

printf "***********\n restore database : \n"
man target / cmdfile='restore'${ORACLE_SID}'_database.rman' > restore${ORACLE_SID}_database.log

if [ $? -ne 0 ]; then
  printf 'restore of backup failed\n' >> $LOG
  exit 1
fi

if test -f "${ORACLE_SID}.cwallet.sso"; then
   mkdir -p /u01/app/oracle/wallet/${ORACLE_SID}
   cp ${ORACLE_SID}.cwallet.sso /u01/app/oracle/wallet/${ORACLE_SID}/
   cp ${ORACLE_SID}.ewallet.p12 /u01/app/oracle/wallet/${ORACLE_SID}/
fi

printf "***********\n Once database restore is finished execute a manual recover \n"
printf "then add tempfiles if needed"
