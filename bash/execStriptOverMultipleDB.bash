# Execute an sql Script over multiple DBs
export $instances=`ps -ef | grep smon_ | cut -f3 -d _ | grep -v ASM | grep -v ^$ | sort | xargs`
export SCRIPT=script.sql
rm stats.tmp
ORAENV_ASK=NO
for i in `ps -ef | grep smon_ | cut -f3 -d _ | grep -v ASM | grep -v ^$ | sort | xargs`
do
ORACLE_SID=${i}; export ORACLE_SID
. oraenv
echo "------ $i ------" >> stats.tmp
echo "----------------" >> stats.tmp
sqlplus '/ as sysdba' @$SCRIPT >> stats.tmp
echo "----------------" >> stats.tmp
done
grep -v \' stats.tmp
rm script.sql


# OD8-CLG-N01: DRI DRI00P DRI00R DRI00U DRIL DSN00F HR900C HR900F
# OD8-CLG-N02: COD CODL HOP HOP00F HOP00R HOP00U HOP01F HOP01R RMANDB SAG SAG00F SAG00R SAG00U SAG01F SAG01R
# ODA-CLG-N01: COD01R DSN DSN00B DSN00D DSN00I DSN00P DSN00R DSN00V HR9 HR900B HR900D HR900I HR900P HR900R HR900V HR9L
# ODA-CLY-N01: COD1 DRI1 DSN00P DSN1 HR900P HR91
# ODA-CLY-N02: COD2 DRI2 DSN2 HR92
# OD8-CLY-N01: HOP1 ORCL1 SAG1
# OD8-CLY-N02: HOP00P HOP2 HOPL ORCL2 SAG00P SAG2
-- ex memory
set head off
set pagesize 200
set linesize 500
show parameter sga_m
show show parameter pga_
exit;
