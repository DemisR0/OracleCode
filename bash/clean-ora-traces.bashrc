#!/bin/ksh
#==============================================================================
#       Script : gestion_traces.ksh
#       Version : 1.0.0
#       Auteur : DBA Middrange
#       Objet : Purges des fichiers oracle core, trace, et audit
#==============================================================================
# Autheur DD-MM-YY Vers. Description
# ------- -------- ----- ------------------------------------------------------
# Specifique a toute version inferieur ▒ 11G
#==============================================================================
#----------------------------------------
# Variables d'environnement a renseigner
#----------------------------------------
ret=30
ORATAB=/etc/oratab
ORACLE_BASE=/u01/app/oracle
LOGDIR=/exploit/logs/dba/housekeeping

find ${LOGDIR} -name clean-ora-traces_* -mtime +7 -exec rm {} \;

#-------------------------------
# Pour chaque ligne de l'oratab
#-------------------------------
cat ${ORATAB} | while read LINE
do
  case ${LINE} in
    \#*) ;;      #comment-line in oratab
      *)
         ORACLE_SID=`echo ${LINE} | awk -F: '{print $1}'`
         ORACLE_HOME=`echo ${LINE} | awk -F: '{print $2}'`
         ACTIVE=`echo ${LINE} | awk -F: '{print $3}'`
         LOGFILE=${LOGDIR}/clean-ora-traces_${ORACLE_SID}_`date +%F`.log
         #-----------------------------------------------------------
         # teste si la variable ORACLE_SID est de longueur non nulle
         #-----------------------------------------------------------
         if [ ! ${#ORACLE_SID} -eq 0 ]
         then
           if [ ${ORACLE_SID} != '*' -a ${ACTIVE} = 'Y' ]
           then
             DIAGHOME=`adrci exec="show homes" | grep ${ORACLE_SID}`
             TRACEHOME=${ORACLE_BASE}"/"${DIAGHOME}"/"trace
             find ${TRACE_HOME} -name "cor*" -mtime +${ret} -print -exec rm -Rf {} \; > $LOGSCR
             find ${REPLOG}/udump -name "*.trc" -mtime +${ret} -print -exec rm -f {} \; > $LOGSCR
             find ${REPLOG}/audit -name "*.aud" -mtime +${ret} -print -exec rm -f {} \; > $LOGSCR
           fi
         fi
         ;;
  esac
done

RET1=$?
if [ "$RET1" = "0" ]
        then
               echo "Traitement OK"
               STATUT=0
        else
    echo " Traitement KO"
    STATUT=1
fi
echo "FIN DU TRAITEMENT"
exit $STATUT
