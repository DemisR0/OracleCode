export ORACLE_HOME=/u01/app/oracle/product/12.2.0/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin
export ORACLE_SID=BFC00D

STATUS=""
timestamp() {
  date +"%d-%m-%Y %H:%M:%S"
}


rman TARGET / <<EndOfCommand

CONFIGURE DEFAULT DEVICE TYPE TO SBT_TAPE;
CONFIGURE CHANNEL DEVICE TYPE SBT_TAPE
PARMS 'SBT_LIBRARY=/opt/veeam/VeeamPluginforOracleRMAN/libOracleRMANPlugin.so'
FORMAT '6100cd95-067e-4581-a2d4-fbf2bbb243f6/RMAN_%I_%d_%T_%U.vab';
CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE SBT_TAPE TO 1;
CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE SBT_TAPE TO 1;
CONFIGURE DEVICE TYPE SBT_TAPE PARALLELISM 4;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE SBT_TAPE TO '%F_RMAN_%d_MLY_FULL_AUTOBACKUP.vab';

RUN {
ALLOCATE CHANNEL VeeamAgentChannel1 DEVICE TYPE SBT_TAPE
PARMS 'SBT_LIBRARY=/opt/veeam/VeeamPluginforOracleRMAN/libOracleRMANPlugin.so'
FORMAT '6100cd95-067e-4581-a2d4-fbf2bbb243f6/RMAN_%I_%d_MLY_FULL_%T_%U.vab';
ALLOCATE CHANNEL VeeamAgentChannel2 DEVICE TYPE SBT_TAPE
PARMS 'SBT_LIBRARY=/opt/veeam/VeeamPluginforOracleRMAN/libOracleRMANPlugin.so'
FORMAT '6100cd95-067e-4581-a2d4-fbf2bbb243f6/RMAN_%I_%d_MLY_FULL_%T_%U.vab';
ALLOCATE CHANNEL VeeamAgentChannel3 DEVICE TYPE SBT_TAPE
PARMS 'SBT_LIBRARY=/opt/veeam/VeeamPluginforOracleRMAN/libOracleRMANPlugin.so'
FORMAT '6100cd95-067e-4581-a2d4-fbf2bbb243f6/RMAN_%I_%d_MLY_FULL_%T_%U.vab';
ALLOCATE CHANNEL VeeamAgentChannel4 DEVICE TYPE SBT_TAPE
PARMS 'SBT_LIBRARY=/opt/veeam/VeeamPluginforOracleRMAN/libOracleRMANPlugin.so'
FORMAT '6100cd95-067e-4581-a2d4-fbf2bbb243f6/RMAN_%I_%d_MLY_FULL_%T_%U.vab';
BACKUP DATABASE PLUS ARCHIVELOG KEEP UNTIL TIME = 'sysdate+92' TAG "MLY_FULL";
}
EXIT;
EndOfCommand

if [ $? -eq 0 ]
then
    STATUS="OK"
else
        STATUS="FAILED"
fi

echo "$(timestamp) MLY FULL $ORACLE_SID $STATUS" >> /veeam/logs/status_veeam_rman_backup.log