#!/bin/bash
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
LOGFILE=${LOGDIR}/oraTracesHousekeeping_`date +%F`.log
find ${LOGDIR} -name oraTracesHousekeeping_* -mtime +7 -exec rm {} \;

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
         ORAENV_ASK=NO
         . oraenv
         ACTIVE=`echo ${LINE} | awk -F: '{print $3}'`
         echo 'cleaning trace files for '${ORACLE_SID} >> ${LOGFILE}
         #-----------------------------------------------------------
         # teste si la variable ORACLE_SID est de longueur non nulle
         #-----------------------------------------------------------
         if [ ! ${#ORACLE_SID} -eq 0 ]
         then
           if [ ${ORACLE_SID} != '*' -a ${ACTIVE} = 'Y' ]
           then
             DIAGHOME=`adrci exec="show homes" | grep ${ORACLE_SID}`
             TRACEHOME=${ORACLE_BASE}"/"${DIAGHOME}"/"trace
             echo 'trace home :'$TRACEHOME >> ${LOGFILE}
             find ${ORACLE_BASE}"/"${DIAGHOME}"/"cdump -name "*" -mtime +${ret} -exec rm -Rf {} \;
             find ${TRACEHOME} -name "*.trc" -mtime +${ret} -exec rm -f {} \;
             find ${TRACEHOME} -name "*.trm" -mtime +${ret} -exec rm -f {} \;
             find ${TRACEHOME} -name "*.aud" -mtime +${ret} -exec rm -f {} \;
             find ${TRACEHOME} -name alert_${ORACLE_SID}_* -ctime +${ret}
             mv ${TRACEHOME}/alert_${ORACLE_SID}.log ${TRACEHOME}/alert_${ORACLE_SID}_`date +%F`.log
             touch ${TRACEHOME}/alert_${ORACLE_SID}.log
             find ${TRACEHOME} -name alert_${ORACLE_SID}_* -ctime +${ret}
             echo '-----------' >> ${LOGFILE}
           fi
         fi
         ;;
  esac
done

RET1=$?
if [ "$RET1" = "0" ]
        then
               echo "Traitement OK" >> ${LOGFILE}
               STATUT=0
        else
    echo " Traitement KO" >> ${LOGFILE}
    STATUT=1
fi
echo "FIN DU TRAITEMENT" >> ${LOGFILE}
exit $STATUT
