#!/usr/bin/bash
#set -vx
#
CmdTitle="Purge logs"
SyntaxHelp="Syntaxe : \n\t"$0
if [[ $1 = '?' ]] || [[ $# -ne 1 ]]
then clear
     echo "\t"$CmdTitle"\n"$SyntaxHelp
     exit 1
fi
export ORACLE_SID=WCSPRD

# ###############################################
#   Positionnement de l'environnement
# ###############################################
#
export ORACLE_SCRIPTS="/oracle/"$ORACLE_SID"/admin/scripts"
export ORACLE_LOGS="/oracle/"$ORACLE_SID"/admin/logs"


# #######################################
#  Purge Traces, Incidents, Cdumps & HM
# #######################################

export ADR_SCRIPT=$ORACLE_SCRIPTS"/Purge_DIAG.param"
export LSTLOG=$ORACLE_LOGS"/Purge_logs.log"

echo `date`"\tStart of job" >> $LSTLOG

export REP1=/oracle/WCSPRD/admin/logs
export REP2=/oracle/WCSPRD/diag/rdbms/wcsprd/WCSPRD/trace
export REP3=/oracle/WCSPRD/audit

echo "Avant Purge :" >> $LSTLOG
echo "\tPurge_DIAG      : "`find $REP1 -name "*Purge_DIAG*" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\tShow_PB         : "`find $REP1 -name "*Show_PB*" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\tLocked_Sessions : "`find $REP1 -name "locked_sessions*" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\ttrc $ORACLE_SID      : "`find $REP2 -name "*.trc" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\ttrm $ORACLE_SID      : "`find $REP2 -name "*.trm" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\taud $ORACLE_SID      : "`find $REP3 -name "*.aud" -exec ls {} \; | wc -l` >> $LSTLOG

find $REP1 -name "*Purge_DIAG*" -mtime +65 -exec rm {} \; >> $LSTLOG
find $REP1 -name "*Show_PB*" -mtime +35 -exec rm {} \; >> $LSTLOG
find $REP1 -name "locked_sessions*" -mtime +35 -exec rm {} \; >> $LSTLOG
find $REP2 -name "*.trc" -mtime +15 -exec rm {} \; >> $LSTLOG
find $REP2 -name "*.trm" -mtime +15 -exec rm {} \; >> $LSTLOG
find $REP3 -name "*.aud" -mtime +15 -exec rm {} \; >> $LSTLOG

echo "Apres Purge :" >> $LSTLOG
echo "\tPurge_DIAG      : "`find $REP1 -name "*Purge_DIAG*" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\tShow_PB         : "`find $REP1 -name "*Show_PB*" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\tLocked_Sessions : "`find $REP1 -name "locked_sessions*" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\ttrc WCSPRD      : "`find $REP2 -name "*.trc" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\ttrm WCSPRD      : "`find $REP2 -name "*.trm" -exec ls {} \; | wc -l` >> $LSTLOG
echo "\taud WCSPRD      : "`find $REP3 -name "*.aud" -exec ls {} \; | wc -l` >> $LSTLOG

echo `date`"\tEnd of job" >> $LSTLOG
