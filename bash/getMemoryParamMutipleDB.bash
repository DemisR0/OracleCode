DBLIST='DSN HR9'
for i in $DBLIST
do
export ORACLE_SID=$i
ORAENV_ASK=NO
. oraenv
echo $i
sqlplus -s  '/ as sysdba' <<EOF
set head off
set linesize 80
select name||' : '||round(value/1024/1024,0) 
from v\$parameter
where name in ('sga_max_size','sga_target','pga_aggregate_limit','pga_aggregate_target','memory_max_target','memory_target')
order by 1 asc;
exit;
EOF
done