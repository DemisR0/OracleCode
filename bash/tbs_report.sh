#!bin/bash
>/tmp/ff38.txt
database_info=`ps -ef | grep pmon | grep ora_ | awk '{print $9 }' | awk -F "_" '{print $3}'`
for sid in $database_info; do
home=`cat /etc/oratab | grep -i $sid | awk -F ":" {'print $2'}`
export ORACLE_SID=$sid
export ORACLE_HOME=$home
export PATH=$home/bin:$PATH
sqlplus /nolog <<EOF  >> /tmp/ff38.txt
connect sys as sysdba
set lines 150 pages 200
col tablespace_name for a50
col servername for a20
select c.db_name,a.tablespace_name,e.servername,round(((a.bytes-b.bytes)/a.bytes)*100,2) percent_used from (select name db_name from v\$database)c,(select host_name servername from v\$instance)e,(select tablespace_name,sum(bytes/1024/1024/1024) bytes from dba_data_files group by tablespace_name)a,(select tablespace_name,sum(bytes/1024/1024/1024) bytes,max(bytes/1024/1024/1024) largest from dba_free_space group by tablespace_name) b where a.tablespace_name=b.tablespace_name and round(((a.bytes-b.bytes)/a.bytes)*100,2)>85;
EOF
if [ `cat /tmp/ff38.txt|wc -l` -gt 8 ]
then
echo "\n Tablespaces are above 85% please check: \n\n`cat /tmp/ff38.txt`"
fi
done
awk '!a[$0]++' /tmp/ff38.txt
cp /tmp/ff38.txt /Oracle_Patching_home

