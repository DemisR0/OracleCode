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

ret=30

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

REP_BDUMP=`echo $bdump | tr -d ' '`


  # Interrogation de la base de données pour obtention du chemin du fichier alert_SID.log
   udump=`${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' <<EOF
    set echo off;
    set head off;
    set feedback off;
    set verify off;
    select LTRIM(value) from v\\$parameter where name='user_dump_dest';
    exit;
    EOF
    `

# enleve les espaces avant et apres la chaine du udump et met la variable dans REP_UDUMP

REP_UDUMP=`echo $udump | tr -d ' '`


  # Interrogation de la base de données pour obtention du chemin du fichier alert_SID.log
   cdump=`${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' <<EOF
    set echo off;
    set head off;
    set feedback off;
    set verify off;
    select LTRIM(value) from v\\$parameter where name='core_dump_dest';
    exit;
    EOF
    `
# enleve les espaces avant et apres la chaine du cdump et met la variable dans REP_CDUMP

REP_CDUMP=`echo $cdump | tr -d ' '`



  # Interrogation de la base de données pour obtention du chemin du fichier alert_SID.log
   adump=`${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' <<EOF
    set echo off;
    set head off;
    set feedback off;
    set verify off;
    select LTRIM(value) from v\\$parameter where name='audit_file_dest';
    exit;
    EOF
    `

# enleve les espaces avant et apres la chaine du adump et met la variable dans REP_ADUMP

REP_ADUMP=`echo $adump | tr -d ' '`

# si le premier caractere de la chaine est  "?"  => cas où l repertoire d'audit apparait sous la forme  ?/rdbms/audit (par ex)
# on remplace "?" par la variable $ORACLE_HOME

REP_ADUMP=`echo $REP_ADUMP | sed  "s#?#${ORACLE_HOME}#"`


   if [ -d ${REP_ADUMP} ];  then

      find ${REP_ADUMP} -name "*.aud" -mtime +${ret} -exec rm -f {} \;
      echo "${ORACLE_SID} => purge ""*.aud"" in ${REP_ADUMP} : OK"
   else
         echo "${ORACLE_SID} => purge ""*.aud"" in ${REP_ADUMP} : KO"
   fi


   if [ -d ${REP_BDUMP} ];  then

      find ${REP_BDUMP} -name "*.trc" -mtime +${ret} -exec rm -f {} \;
      echo "${ORACLE_SID} => purge ""*.trc"" in ${REP_BDUMP} : OK"
   else 
	echo "${ORACLE_SID} => purge ""*.trc"" in ${REP_BDUMP} : KO" 
   fi 

   if [ -d ${REP_CDUMP} ];  then

      find ${REP_CDUMP} -name "cor*" -mtime +${ret} -exec rm -Rf {} \;
      echo "${ORACLE_SID} => purge ""cor*"" in ${REP_CDUMP} : OK"
   else
        echo "${ORACLE_SID} => purge ""cor*"" in ${REP_CDUMP} : KO "
   fi


   if [ -d ${REP_UDUMP} ];  then

      find ${REP_UDUMP} -name "*.trc" -mtime +${ret} -exec rm -f {} \;
      echo "${ORACLE_SID} => purge ""*.trc"" in ${REP_UDUMP} : OK"
   else 
	echo "${ORACLE_SID} => purge ""*.trc"" in ${REP_UDUMP} : KO"
   fi 


             fi
           fi
          ;;
    esac
done
