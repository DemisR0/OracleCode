#==============================================================================
#       Script : gestion_alert.ksh
#       Version : 1.0.0
#       Auteur : Blaise KIBONZI DBA
#       Objet : Historisation et purge des fichiers alert<SID>.log
#       Regle : 1 fichier historique par mois
#==============================================================================
# Autheur DD-MM-YY Vers. Description
# ------- -------- ----- ------------------------------------------------------
#         00-00-00 1.0.0
#
##==============================================================================
#set -x

#----------------------------------------
# Variables d'environnement a renseigner
#----------------------------------------

Jour=`date +%d`
Mois=`date +%b`

os=`uname -a | awk '{print $1}'`
if [ $os = 'SunOS' ]
   then
     ORATAB=/var/opt/oracle/oratab
   else
     ORATAB=/etc/oratab
fi

cat ${ORATAB} | while read LINE
do
   case ${LINE} in
      \#*) ;;      # comment-line in oratab
        *)
           ORACLE_SID=`echo ${LINE} | awk -F: '{print $1}'`
           ORACLE_HOME=`echo ${LINE} | awk -F: '{print $2}'`
           ACTIVE=`echo ${LINE} | awk -F: '{print $3}'`


	if [ "$ORACLE_SID" = '*' ] ; then 
		ORACLE_SID=""
	fi

           #-----------------------------------------------------------
           # teste si la variable ORACLE_SID est de longueur non nulle
           #-----------------------------------------------------------
           if [ ! ${#ORACLE_SID} -eq 0 ]
           then
             if [ ${ORACLE_SID} != '*' -a ${ACTIVE} = 'Y' ]
             then

   # Positionnement des variables d'environnment via ORAENV
   export ORACLE_HOME;
   export ORACLE_SID;
   export PATH=$ORACLE_HOME/bin:$PATH
   export ORAENV_ASK=NO;
   . oraenv;


  # Interrogation de la base de données pour obtention du chemin du fichier alert_SID.log
   bdump=`${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' <<EOF
    set echo off;
    set head off;
    set feedback off;
    set verify off;
    select LTRIM(value) from v\\$parameter where name='background_dump_dest';
    exit;
    EOF
    `

# enleve les espaces avant et apres la chaine du bdump et met la variable dans bdump2

bdump2=`echo $bdump | tr -d ' '`

REPLOG=${bdump2}

   if [ -d ${REPLOG} ];  then

	log=${REPLOG}/alert_${ORACLE_SID}.log

    	if [ -f ${log} ]; then 

        	if [ "${Jour}" == "01" ] ;
        	then
                 	> ${log}${Mois}
        	fi
                cat ${log} >> ${log}${Mois}
                > ${log}
chmod 640 ${log}${Mois}
	echo "${ORACLE_SID} => rotation $log : OK"
	chmod 640 $log 
    	else
		echo "${ORACLE_SID} => rotation $log : KO (fichier non trouve)"
   	fi 

   else 
	echo "${ORACLE_SID} => rotation $log : KO (repertoire non trouve)" 
   fi
             fi
           fi
          ;;
    esac
done
