#! /usr/bin/ksh
set -x
#--------------------------------------------------------------------------------
# @(#)SCRIPT                    : rotation_listener_log.ksh
#--------------------------------------------------------------------------------
# @(#)Application               : IBM/CARREFOUR
# @(#)Fonction                  : Rotation du fichier listener.log
# @(#)
# @(#)SCR-Version               : 1.00
# @(#)Auteur                    : DBA IBM-CARREFOUR/
# @(#)Auteur                    : Blaise KIBONZI(version initiale)
# @(#)Date de creation          : 06/06/2011 15:04
# @(#)Parametres d'entree       :
# @(#)Codes retour              : 0 si correct
# @(#)                            1
# @(#)                            2
# @(#)                            3
# @(#)                            4
# @(#)Utilisateur               : compte oracle unix proprietaire du listener
# @(#)
# @(#)Commentaires              :
# @(#)
# @(#)
# @(#)
# @(#)Etapes du script          : (Grandes parties de son deroulement)
#--------------------------------------------------------------------------------
# @(#)Modifications             :
#--------------------------------------------------------------------------------
# prerequis : le listener doit �tre demarre
#
# format date et mois
Jour=`date +%d`
Mois=`date +%b`


#################################################################################
# boucle sur les process listener qui sont demarres sur le serveur              #
# et pour chaque process trouve recupere :                                      #
# - le numero de process                                                        #
# - le nom du user ayant lance de process                                       #
# - la chaine contenant le ORACLE_HOME                                          #
# - le nom du listener                                                          #
#################################################################################

for PS  in `ps -ef | grep "tnslsnr" | grep -v "grep" | awk '{print $2}'`
do
        NOM_UZER=`ps -ef | grep ' $PS ' | grep -v "grep" | awk '{print $1}'`
        NOM_LISTENER=`ps -ef | grep ' $PS ' | grep -v "grep" | awk '{print $10}'`
        CHEMIN_TSNRCTL=`ps -ef | grep ' $PS ' | grep -v "grep" | awk '{print $9}'`


        # extraction de la sous chaine ORACLE_HOME a partir du chemin complet de la commande TSNRCTL
	# ORACLE_HOME = la sous-chaine qui precede bin
        ORACLE_HOME=${CHEMIN_TSNRCTL%%bin*}

	export ORACLE_HOME


        # On verifie si le user qui lance le script est le meme que celui a qui  a demarre le listener

        EXECUTEUR=`whoami`;

        if [ $EXECUTEUR != $NOM_UZER ] ; then
                # Si le user qui execute le script n est pas celui  qui a demarre le listener
                echo " Le user \"$EXECUTEUR\" n a pas pu traiter le cas du listerner \"$NOM_LISTENER\" car appartient a un autre utilisateur !"

        else

                # Si le user qui execute le script est le meme que celui qui a demarre le listener
		# On genere un fichier nomme status_listener.log dans lequel on va recuperer l'emplacement exact du fichier listener.log
		$ORACLE_HOME/bin/lsnrctl status $NOM_LISTENER > status_listener.log

                # Recuperation du nom absolu du fichier listener.log
                FICHIER_LISTENER_LOG=$(cat status_listener.log | grep "Listener Log File" | awk '{print $4}')
                # A partir du nom absolu du fichier listener.log, extraction de la sous chaine correspondant au repertoire du fichier log du listener
                # (on recupere toute la chaine avant le dernier /)
                REP_LISTENER_LOG=${FICHIER_LISTENER_LOG%/*}
                # date du jour a ajouter au fichier sauvegarde
                SAV=`/bin/date +%d%m%y%H%M%S`;

                # Switch de la log du listener vers un fichier temporaire temp.log
	        # ATTENTION NE PAS TOUCHE A L'INDENTATION DU SCRPT SINON BUG !!!!
                if [ -f $FICHIER_LISTENER_LOG ] ; then
$ORACLE_HOME/bin/lsnrctl  <<EOF
set current_listener  $NOM_LISTENER
set log_file  $REP_LISTENER_LOG/temp.log
EOF
                      # move de l'ancien fichier listener.log en nom_fichier_listener.log.date_du_jour (variable SAV)
                        mv $FICHIER_LISTENER_LOG $FICHIER_LISTENER_LOG.$SAV
                # Reswitch de la log du listener vers un tout nouveau fichier nom_fichier_listener.log
$ORACLE_HOME/bin/lsnrctl <<EOF
set current_listener  $NOM_LISTENER
set log_file  $FICHIER_LISTENER_LOG
EOF

# On concatene le contenu du fichier temp.log avec celui de l'ancien fichier listerner qui avait ete sauvegarde en $FICHIER_LISTENER_LOG.$SAV
                        cat $REP_LISTENER_LOG/temp.log >> $FICHIER_LISTENER_LOG.$SAV ;

                        # On supprime le fichier temp.log
                        rm $REP_LISTENER_LOG/temp.log;


 #  Gestion de la retention des anciens fichiers log  du listener
 # Le script est execute tous les jours. Il cree un nouveau fichier log pour le listener. Celui de la veille  est ajoute au fichier du mois.


              # Si premier jour du mois , alors creer un fichier nom_fichier_listenerMOIS
              if [ "${Jour}" = "01" ]
               then
                 > ${FICHIER_LISTENER_LOG}${Mois}
               fi

               # ajouter le contenu du fichier log du listener de la veille au fihier log listener du mois.
               cat $FICHIER_LISTENER_LOG.$SAV >> ${FICHIER_LISTENER_LOG}${Mois};
               rm  $FICHIER_LISTENER_LOG.$SAV ;
               find $REP_LISTENER_LOG -name *.log -mtime +60 -exec rm {} \; # suprimme les an
           else
                        echo "Fichier listener.log non trouve ......";
                        exit 1 ;
            fi ;



        fi;
chmod 640 ${FICHIER_LISTENER_LOG}${Mois}
gzip ${FICHIER_LISTENER_LOG}${Mois}
done
