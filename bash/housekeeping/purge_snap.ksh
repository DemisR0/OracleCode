
#!/bin/ksh

# First, we must set the environment . . . .
ORACLE_SID=$1
export ORACLE_SID
ORACLE_HOME=`cat /etc/oratab | grep $ORACLE_SID | cut -f2 -d :`
# cat /etc/oratab | grep DEMPRE01 |cut -f2 -d :
export ORACLE_HOME
echo "oracle home1"
echo $ORACLE_HOME
PATH=$ORACLE_HOME/bin:$PATH
export PATH
echo $PATH
echo "Oracle home"
echo $ORACLE_HOME
$ORACLE_HOME/bin/sqlplus system/oracle <<!

select * from v\$database;
connect perfstat/perfstat
define losnapid=$2
define hisnapid=$3
@sppurge
exit
!
