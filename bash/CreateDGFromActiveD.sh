#!/bin/bash
#set -x
. /home/oracle/.bash_profile
export BASE=/home/oracle/scripts
export LOG=${BASE}/log
export TRG_DB=$1
export AUX_DB=$2
export PATH=${PATH}:/usr/local/bin

if [ $# -ne 2 ]
then
echo " $0 <TargetDB> <AuiliaryDB>"
exit 0
fi
rman << Eof
spool log to '${BASE}/log/${TRG_DB}_2_${AUX_DB}.log'
connect target sys/xxxxxx@${TRG_DB}
connect  auxiliary sys/xxxxxx@${AUX_DB}
run {
allocate channel prmy1 type disk;
allocate auxiliary channel stby type disk;
duplicate target database for standby from active database;
}
spool log off
exit
Eof
