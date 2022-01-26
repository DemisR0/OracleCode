mkdir /tmp/fred
cd /tmp/fred
echo 'select v.version,t.version from v$instance v ,v$timezone_file;'> script.sql
echo 'exit;' >> script.sql
ORAENV_ASK=NO
rm stats
for i in `ps -ef | grep smon_ | cut -f3 -d _ | grep -v ASM | grep -v ^$ | sort | xargs`
do
  export ORACLE_SID=$i
  . oraenv
  sqlplus '/ as sysdba' @script.sql | grep '\.' >> stats
done
rm script.sql

grep '^[0-9]' stats | sort
