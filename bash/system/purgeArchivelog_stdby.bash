#!/bin/bash
#set -x
. /home/oracle/.bash_profile
export BASE=/home/oracle/scripts
export LOG=${BASE}/log
export TMP=${BASE}/tmp
export ORACLE_SID=$1
export ORAENV_ASK=NO
export PATH=${PATH}:/usr/local/bin

if [ $# -ne 1 ]
then
echo " $0 <ORACLE_SID> "
exit 10
fi
#.  /usr/local/bin/oraenv
.  oraenv
sqlplus -s / as sysdba << ARCH
set head off
set feedback off
spool ${TMP}/${ORACLE_SID}.rman
prompt run
prompt {
select 'delete noprompt archivelog  until sequence '||(max(sequence#) - 50)||' thread  '||thread#||' ;'  from v\$archived_log where applied='YES'
and resetlogs_time= (select  resetlogs_time from v\$database)  group by thread# ;
prompt }
spool off
exit
ARCH

rman nocatalog  target /  cmdfile=${TMP}/${ORACLE_SID}.rman log=${LOG}/${ORACLE_SID}.log
