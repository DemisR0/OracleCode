dbList=`cut -d: -f1 /etc/oratab | grep -i '^[A-Z]'`
export ORAENV_ASK=NO
for i in $dbList
do
  export ORACLE_SID=$i
  . oraenv
  echo 'stop: '$ORACLE_SID
sqlplus '/ as sysdba' <<EOF
shutdown immediate;
exit;
EOF
  ps -ef | grep $ORACLE_SID
done
