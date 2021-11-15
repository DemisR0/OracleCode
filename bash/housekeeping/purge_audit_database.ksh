#!/bin/ksh
#-------------------------------------------------------------------------------------------
# Script ksh
# Purge des logs de la table SYS.AUD$
#-------------------------------------------------------------------------------------------

#--------------------------------------------------------------
#------ Check environment.
#--------------------------------------------------------------
cd /home/oracle/scripts

var=$(ls -l /home/oracle/scripts/purge_audit_database.log | tr -s ' ' | cut -d" " -f5)

if [[ $var -gt 5000000 ]]
then
cp purge_audit_database.log purge_audit_database.log.old
rm purge_audit_database.log
fi

touch ./deviation_audit.log
ps -ef | grep pmon | grep -v grep > ./instance.txt

while IFS= read -r line
do
var=$(echo $line | tr -s ' ' | cut -d" " -f5)

if [[ $var == *:* ]]
then
inst=$(echo $line | tr -s ' ' | cut -d" " -f8 | cut -d_ -f3)
else
inst=$(echo $line | tr -s ' ' | cut -d" " -f9 | cut -d_ -f3)
fi

echo $inst >> ./deviation_audit.log
done < ./instance.txt

echo "################################# Debut du script le : $(date)####################################" >> purge_audit_database.log

while read line
do

echo "----------------------------------------------------------------------------------------- $line "
if [ -n $line ]
then
export ORACLE_HOME=$(cat /etc/oratab | grep $line: | grep -v "#" |cut -d":" -f2)
export ORACLE_SID=$line

#--------------------------------------------------------------
#------ Check What Tablespace is used.
#--------------------------------------------------------------
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
set line 200
spool tablespace.log
SELECT table_name, tablespace_name FROM dba_tables WHERE  table_name = 'AUD$' ORDER BY table_name;
EOF

tablespace=$(grep "AUD" tablespace.log | tr -s ' ' | cut -d" " -f2)

#--------------------------------------------------------------
#------ Gather Audit Parameter and Tablespace Size.
#--------------------------------------------------------------
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
set line 180
set heading off
spool result_audit_trail.log
show parameter audit_trail
spool off
spool size.log
SELECT A.tablespace_Name, A.Alloue, B.Occupe
FROM (select tablespace_name, sum(bytes)/1024/1024 AS ALLOUE from dba_data_files group by tablespace_name) a,
(select tablespace_name, Sum(bytes)/1024/1024 AS OCCUPE from dba_segments group by tablespace_name) b
WHERE B.tablespace_Name = A.tablespace_Name
AND A.tablespace_Name = '$tablespace';
spool off
EOF

audit=$(grep "audit_trail" result_audit_trail.log | grep string | tr -s ' ' | cut -d" " -f3)
size=$(grep $tablespace size.log | tr -s ' ' | cut -d" " -f3 | cut -d"." -f1 | cut -d"," -f1)
if [ -z "$size" ]; then size=0; fi
alloue=$(grep $tablespace size.log | tr -s ' ' | cut -d" " -f2)
freesize=$(($alloue-$size))

#-----------------------------------------------------------
# Check Audit Parameter
#-----------------------------------------------------------
if [[ $audit == *DB* ]] || [[ $audit == *TRUE* ]]
then

if [[ $tablespace == SYSAUX ]] | [[ $tablespace == SYSTEM ]]
then

if [[ $freesize -lt 50 ]]
then
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" @trunc_table.sql

else
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" @delete_rows_01.sql
fi

else

if [[ $freesize -lt 50 ]]
then
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" @trunc_table.sql

else
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" @delete_rows_02.sql
fi
fi
echo "espace libre : $freesize" >> /home/oracle/scripts/purge_audit_database.log
cat ./aud_info.log >> /home/oracle/scripts/purge_audit_database.log
fi

fi
done < ./deviation_audit.log

rm /home/oracle/scripts/instance.txt
rm /home/oracle/scripts/result_audit_trail.log
rm /home/oracle/scripts/deviation_audit.log
rm /home/oracle/scripts/size.log
rm /home/oracle/scripts/tablespace.log
rm /home/oracle/scripts/aud_info.log 

exit 0
