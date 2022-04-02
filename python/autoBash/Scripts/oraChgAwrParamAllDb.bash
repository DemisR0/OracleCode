ORAENV_ASK=NO
for i in `ps -ef | grep smon_ | cut -f3 -d _ | grep -v ASM | grep -v ^$ | sort | xargs`
do
ORACLE_SID=${i}; export ORACLE_SID
. oraenv
echo $ORACLE_SID
sqlplus "/ as sysdba" <<EOF
execute dbms_workload_repository.modify_snapshot_settings(interval => 60,retention => 43200)\;
exit;
EOF
done
