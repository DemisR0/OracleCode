#!/bin/ksh
#==============================================================================
# Script : purge_rep_logs.ksh
# @(#) Version : 
# Auteur : DBA CARREFOUR
# Objet : Purge du repertoire $HOME_ORACLE/logs 
#==============================================================================
# Autheur DD-MM-YY Vers. Description
# Blaise KIBONZI 18/08/2011 : version initiale
# ------- -------- ----- ------------------------------------------------------
#         00-00-00 1.0.0
#==============================================================================
#set -x
#----------------------------------------
# Variables d'environnement a renseigner
#----------------------------------------
# retention 
ret=10
# emplacement des fichiers a purger 
REPLOG=$HOME/logs
# purge 
find ${REPLOG} -name "*.*" -mtime +${ret} -print -exec rm -f {} \;
if [ $? != 0 ]
then
 echo "Erreur !!!!!!!"
 exit 1
else 
 echo "Execution terminée avec succes !"
 exit 0
fi 

