#!/usr/bin/ksh
##########################################################################################
# Script name:  rman_function.ksh
# Description:  Function library for Rman backup script
# Authors:      BaaS Team - Brno, Czech Republic
#               Milan Dufek <milan_dufek@cz.ibm.com>
# Version:      1.1 (15.01.2018)     
##########################################################################################
# function delete_obsolete_days
# function delete_obsolete_versions
# function backup_archivelog
# function backup_archivelog_emergency
# function backup_controlfile
# function backup_spfile
# function backup_db_full_offline
# function backup_db_inc0_offline
# function backup_db_inc1_offline
# function backup_db_inc2_offline
# function backup_db_full_online
# function backup_db_inc0_online
# function backup_db_inc1_online
# function backup_db_inc2_online
##########################################################################################

# number sequence generator
seqGen () {
    [ $# -lt 2 ] && LIMIT=1 || LIMIT=$1
    COUNTER=$1
    while [ $COUNTER -le $LIMIT ]; do
        echo $COUNTER
        (( COUNTER+=1 ))
    done
}

# is valid number 1 or higher
isValidNumber () {
    NUMBER=$1
    expr $NUMBER + 0 >/dev/null 2>&1
    [ $? -ne 0 ] && return 1 || return 0
}

# print message
printMsg () {
    $LOGGING && echo "$@" >>$LOG
    $SCREEN  && echo "$@"
    return 0
}

# print file content
printFile () {
    $LOGGING && cat "$@" >>$LOG
    $SCREEN  && cat "$@"
    return 0
}

# print error, exit & clean-up & exit
exitScript () {
    rm -f ${TMP_DIR}/$$.* ${WORK_DIR}/$$.* $PIDFILE >/dev/null 2>&1
    printMsg "Exiting with RC ($1)"
    exit $1
}

# get current timestamp in seconds from UNIX epoch beginning
getTimestamp () {
    TS=$(perl -le 'print time()')
    echo $TS
    return 0
}

# convert timestamp to datetime in format: YYYY-MM-DD HH:mm:ss (e.g.: 2017-11-22 13:37:00)
timestampToDatetime () {
    CURRENT_TS=$(getTimestamp)
    [ ! -z "$1" ] && TS_DATETIME=$1 || TS_DATETIME=$(CURRENT_TS)
    DATETIME=$(perl -MPOSIX=strftime -le 'print strftime("%Y-%m-%d %T", localtime('$TS_DATETIME'))')
    echo $DATETIME
    return 0
}

# check if NOW is in business hours
inBussinessHours () {
    [ "$CHECK_BUSINESS_HOURS" != "yes" ] || return 1
    [ $# -ne 2 ] && return 2
    BUSINESS_FROM=$(echo $1 | tr -d ':')
    BUSINESS_TO=$(echo $2 | tr -d ':')
    NOW=$(date '+%H%M')
    if [[  $NOW -gt $BUSINESS_FROM && $NOW -le $BUSINESS_TO ]]; then
        # Is in business hours
        return 0
    else
        # Is out of business hours
        return 1
    fi
}

# Function delete_obsolete_days
delete_obsolete_days () {
    # print sql function
    echo "allocate channel for delete device type '$DEVICE' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';
delete noprompt force obsolete recovery window of ${DELETE_OBSOLETE_RETENTION} days;
release channel;"
}

# function delete_obsolete_versions
delete_obsolete_versions () {
    # print sql function
    echo "allocate channel for delete device type '$DEVICE' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';
delete noprompt force obsolete redundancy ${DELETE_OBSOLETE_RETENTION};
release channel;"
}

# check tsm connections
checkTsmConnection () {
    printMsg "Checking TSM connection..."
    dsmc query session -optfile=$DSMI_OPTFILE 1>/dev/null 2>&1
    return $?
}

# list Rman backed-up objects
printRmanBackups () {
    printMsg "Checking RMAN backed-up object list..."
    RMAN_BACKUP_LIST=${TMP_DIR}/$$.rman_backup_${ORACLE_SID}.list
    su - $ORA_USER -c "$ORAENV; NLS_DATE_FORMAT='MM/DD/YYYY HH24:MI:SS'; $RMAN_CONNECTION <<EOD >$RMAN_BACKUP_LIST 2>&1
list backup;
EOD" 1>/dev/null 2>&1
    if [ $? -ne 0 ]; then
        printMsg "Cannot get Rman backup object list"
        return 1
    else
        grep -iE "handle|piece" $RMAN_BACKUP_LIST
        return 0
    fi
}

# function to check undeleted backups on TSM server (TSM delete obsolete days + EXTRA RETENTION)
checkUndeletedBackups () {
    TSM_BACKUP_LIST=${TSM_DIR}/$$.tsm_backup_${ORACLE_SID}.list
    # determine TODATE and TOTIME values
    DAY_IN_SECONDS=86400
    CURRENT_TS=$(getTimestamp)
    EXTRA_RET_POL=$(expr $DELETE_OBSOLETE_RETENTION + $EXTRA_RETENTION)
    TO_DATETIME_TS=$(expr $CURRENT_TS - $EXTRA_RET_POL \* $DAY_IN_SECONDS)
    TO_DATETIME=$(timestampToDatetime $TO_DATETIME_TS)
    TODATE=$(echo $TO_DATETIME | awk '{ print $1 }')
    TOTIME=$(echo $TO_DATETIME | awk '{ print $2 }')
    printMsg
    printMsg "Checking undeleted backups before $TODATE $TOTIME..."
    # Get TSM objects list
    printMsg "dsmc query backup \"${TDPO_FS}/*\" -subdir=yes -dateformat=3 -todate=$TODATE -totime=$TOTIME -optfile=$DSMI_OPTFILE"
    dsmc query backup "${TDPO_FS}/*" -subdir=yes -dateformat=3 -todate=$TODATE -totime=$TOTIME -optfile=$DSMI_OPTFILE >$TSM_BACKUP_LIST 2>&1
    if [[ $? -ne 0 && $? -ne 8 ]]; then
        ERROR_LOG=$(grep -i errorlog $DSM_DIR/dsm.sys | grep $ORACLE_SID | tail -1 | awk '{ print $2 }')
        printMsg "Problem on TSM client side."
        printMsg "Check ERRORLOG - $ERROR_LOG"
        return $ERR_TSM_CLIENT
    fi
    TSM_OBS_BACKUPS=${TMP_DIR}/$$.tsm_obs_backups_${ORACLE_SID}.list
    >$TSM_OBS_BACKUPS
    grep -E "^API" $TSM_BACKUP_LIST | awk '{ print $NF }' | sed 's+.*/++' | while read LINE; do
        echo "delete backup -noprompt ${TDPO_FS}/$LINE" >>$TSM_OBS_BACKUPS
    done
    CNT_OBS_BACKUPS=$(wc -l $TSM_OBS_BACKUPS | awk '{ print $1 }')
    if [ $CNT_OBS_BACKUPS -eq 0 ]; then
        printMsg "No undeleted backup found before $EXTRA_RET_POL days"
        return 0
    else # print undeleted backups
        printMsg "$CNT_OBS_BACKUPS undeleted backups found and need to be deleted manually"
        printMsg "TSM commands to use: dsmc -optfile=$DSMI_OPTFILE"
        printFile $TSM_OBS_BACKUPS
        printMsg
        # find last FULL backup date
        LAST_L0_BACKUP_DATE=$(dsmc query backup "${TDPO_FS}/*" -subdir=yes -dateformat=3 -optfile=$DSMI_OPTFILE | grep ${TAG_BDB}_${TAG_L0} \
        | sort -u -k 4,4 | tail -1 | awk '{ print $4,$5 }')
        if [ $? -eq 0 ]; then
            printMsg "WARNING: Before removing any backup data ensure when the last level 0 backup completed succesfully"
            printMsg "Last level 0 backup data piece found from $LAST_L0_BACKUP_DATE"
        fi
        return $ERR_OBS_TSM_DATA
    fi
}

# check API:ORACLE filespaces
checkFilespaces () {
    API_FILESPACE=${TMP_DIR}/$$.FS_API_${ORACLE_SID}.list
    printMsg
    printMsg "Checking number of API:ORACLE filespaces..."
    printMsg "dsmc query filespace -optfile=$DSMI_OPTFILE | grep API:ORACLE"
    # TODO nekdy je FS JFS2 a ne API:ORACLE
    dsmc query filespace -optfile=$DSMI_OPTFILE | grep -E "API:ORACLE|JFS" >$API_FILESPACE 2>&1
    if [ $? -ne 0 ]; then
        printMsg "Cannot determine number of API:ORACLE filespaces"
        printMsg
        return $ERR_GET_API_FS
    fi
    NUMBER_OF_FILESPACES=$(wc -l $API_FILESPACE | awk '{ print $1 }')
    if [ "$NUMBER_OF_FILESPACES" != "1" ]; then
        printMsg "There are $NUMBER_OF_FILESPACES API:ORACLE filespaces instead, some should be deleted manually"
        printMsg "Currently setup API:ORACLE filespace is $TDPO_FS"
        printMsg "Following file space(s) found: "
        printFile $API_FILESPACE
        printMsg 
        printMsg "TSM commands to use: "
        printMsg "  dsmc -optfile=$DSMI_OPTFILE"
        printMsg "    query filespace"
        printMsg "    delete filespace <other_filespaces>"
        printMsg "If you need to connect to Rman: " 
        printMsg "su - $ORA_USER -c \"ORACLE_SID=$ORACLE_SID; ORAENV_ASK=NO; . oraenv -s\""
        printMsg "allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';"
        printMsg
        return $ERR_MORE_API_FS
    else
        printMsg "Only one API:FILESPACE found"
        printFile $API_FILESPACE
        printMsg 
    fi
    
    rm -f $API_FILESPACE
    return 0
}

# check control_file_record_keeptime value
checkControlFileRecordKeeptime () {
    printMsg
    printMsg "Checking control file record keep time..."
    RETENTION_POLICY_TARGET=$(expr $DELETE_OBSOLETE_RETENTION + $EXTRA_RETENTION )
    CONTROL_FILE_RECORD_KEEP_TIME=$(su - $ORA_USER -c "$ORAENV; echo \"SHOW PARAMETER KEEP_TIME\" | sqlplus \"/ as sysdba\"" 2>/dev/null | grep -i keep_time | awk '{ print $3 }')
    if [[ -z $CONTROL_FILE_RECORD_KEEP_TIME || $(isValidNumber $CONTROL_FILE_RECORD_KEEP_TIME; echo $?) -ne 0 ]]; then
        printMsg "Cannot get information from sqlplus"
        exitScript $ERR_GET_SQLPLUS
    fi
    if [ $CONTROL_FILE_RECORD_KEEP_TIME -lt $RETENTION_POLICY_TARGET ]; then
        printMsg "Value of control_file_record_keep_time in RMAN ($CONTROL_FILE_RECORD_KEEP_TIME) - is lower that expected ($RETENTION_POLICY_TARGET)"
        printMsg "If you do not use a catalog, control_file_record_keep_time must be set correctly"
        printMsg "You can corrent the value in Rman using: "
        printMsg "su - $ORA_USER -c \"ORACLE_SID=$ORACLE_SID; ORAENV_ASK=NO; . oraenv -s\""
        printMsg "allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=${OPTFILE_PATH}/tdpo_${ORACLE_SID}.opt)';"
        printMsg "alter system set control_file_record_keep_time=$RETENTION_POLICY_TARGET scope=both"
        printMsg
        return 1
    else
        printMsg "Value of control_file_record_keep_time in RMAN is $CONTROL_FILE_RECORD_KEEP_TIME"
        return 0
    fi
}

# check retention policy
checkRetentionPolicy () {
    printMsg
    printMsg "Checking retention policy in RMAN catalog..."
    RETENTION_POLICY_TARGET=$(expr $DELETE_OBSOLETE_RETENTION + $EXTRA_RETENTION )
    RETENTION_POLICY=$(su - $ORA_USER -c "$ORAENV; echo \"SHOW RETENTION POLICY;\" | $RMAN_CONNECTION | grep \"RETENTION POLICY TO RECOVERY WINDOW\" | awk '{ print $8 }' ")
    if [ $RETENTION_POLICY -lt $RETENTION_POLICY_TARGET ]; then
        printMsg "Value of RETENTION POLICY TO RECOVERY WINDOW OF $RETENTION_POLICY DAYS - is lower that expected ($RETENTION_POLICY_TARGET)"
        printMsg "If you use a catalog, RETENTION POLICY TO RECOVERY WINDOW must be set correctly"
        printMsg "You can corrent the value in Rman using: "
        printMsg "su - $ORA_USER -c \"ORACLE_SID=$ORACLE_SID; ORAENV_ASK=NO; . oraenv -s\""
        printMsg "CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF $RETENTION_POLICY_TARGET DAYS;"
        printMsg 
        return 1
    else
        printMsg "Value of RETENTION POLICY TO RECOVERY WINDOW OF $RETENTION_POLICY DAYS is $RETENTION_POLICY_TARGET"
        return 0
    fi
}

# check status of change block tracking
checkBlockChangeTracking () {
    printMsg
    printMsg "Checking Rman block change tracking status..."
    CBT_STATUS=$(su - $ORA_USER -c "$ORAENV; echo 'select status from v\$block_change_tracking;' | sqlplus \"/ as sysdba\"" 2>/dev/null | grep ABLED)
    if [ "$CBT_STATUS" == "ENABLED" ]; then
        printMsg "Block change tracking status is ENABLED"
        return 0
    elif [ "$CBT_STATUS" == "DISABLED" ]; then
        printMsg "Block change tracking status is DISABLED"
        return 1
    else
        printMsg "Block change tracking status is UNKNOWN"
        return 2
    fi
}

# print info about current function run
printBackupInfo () {
    printMsg
    printMsg "Starting $FUNCTION for instance ${ORACLE_SID} with following settings: "
    printMsg "ORACLE SID = $ORACLE_SID"
    printMsg "ORA_USER = $ORA_USER"
    printMsg "Oracle version: $ORACLE_VERSION"
    printMsg "RMAN_CATALOG = $RMAN_CATALOG"
    printMsg "Mode = ${ONOFF}LINE"
    printMsg "CHANNELS = $CHANNELS"
    printMsg "MAXSETSIZE = $MAXSETSIZE"
    printMsg "MAXPIECESIZE = $MAXPIECESIZE"
    printMsg "MAXOPENFILES = $MAXOPENFILES"
    printMsg "FILESPERSET = $FILESPERSET"
    printMsg "RMAN_COMPRESSION = $RMAN_COMPRESSION"
    printMsg "DEVICE = $DEVICE"
    printMsg "TDPO_OPTFILE = $TDPO_OPTFILE"
    printMsg "DSMI_OPTFILE = $DSMI_OPTFILE"
    printMsg "TDPO_FS = $TDPO_FS"
    printMsg
    printMsg "Command executed: $EXECUTED_CMD"
    printMsg
}

# function backup_archivelog
backup_archivelog () {
    # print sql function
    echo "run {
        allocate channel a1 type '$DEVICE' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';
        configure controlfile autobackup format for device type sbt to '${TAG_CTL_ARCH}.%F';
        backup filesperset=$FILESPERSET (archivelog all format='${TAG_ARCH}.%d_%t_%s_%p' tag='${TAG_ARCH}.${ORACLE_SID}.${START_TIMESTAPM}' delete input);
        release channel a1;
    }"
}

# emergency archlog backup
backup_archivelog_emergency () {
    SQL_LOGDIR=/tmp/$$.req.sql
    echo "select value from v\$parameter where (name='log_archive_dest' and value is not null) or (name='log_archive_dest_1' and value is not null);" >$SQL_LOGDIR 
    echo "exit;" >> $SQL_LOGDIR
    ARCHIVELOGS_DIR=$(su - $ORA_USER -c "$ORAENV; sqlplus -s '/ as sysdba' @$SQL_LOGDIR | grep $ORACLE_SID")
    ARCHIVELOGS_DIR=$(echo $ARCHIVELOGS_DIR | awk '{ print $NF }' | cut -d '=' -f 2)
    if [ ! -d $ARCHIVELOGS_DIR ]; then
        printMsg "Archivelogs directory does not exist..."
        exitScript 255
    fi
    # determine % of usage in archlog dir
    if [ "$OS" == "aix" ]; then
        PCTUSAGE=$(df $ARCHIVELOGS_DIR | awk '{if(NR>1) print $4}' | sed "s/%//g")
    else
        PCTUSAGE=$(df $ARCHIVELOGS_DIR | awk '{if(NR>1) print $5}' | sed "s/%//g")
    fi
    # compare current usage and limit usage
    if [ $PCTUSAGE -ge $ARCHLOGFS_USAGE_LIMIT ]; then
        printMsg "Beginning RMAN backup archivelog emergency because FS is greater than ${RETENTION_OR_FSUSAGE}: $(date '+%Y-%m-%d %H:%M:%S')" 
        printMsg "Calling standard backup_archivelog function..."
        RMAN_SCRIPT=${TMP_DIR}/$$.$FUNCTION.$ORACLE_SID.sql
        backup_archivelog | sed -e 's/^[ \t]*//' >$RMAN_SCRIPT     
        su - $ORA_USER -c "$ORAENV; $RMAN_CONNECTION @$RMAN_SCRIPT" >>$LOG 2>&1
        RMAN_RC=$?
        rm -f $RMAN_SCRIPT $SQL_LOGDIR
        printMsg "End of RMAN backup archivelog emergency: $(date '+%Y-%m-%d %H:%M:%S')"
        retutn $RMAN_RC
    else
        printMsg "Archive logs dir usage is ${PCTUSAGE}, which is less than ${ARCHLOGFS_USAGE_LIMIT} ..."
        return 0
    fi
}

# function backup_controlfile
backup_controlfile () {
    # print sql function
    echo "run {
    allocate channel c1 type '$DEVICE' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';
    configure controlfile autobackup format for device type sbt to '${TAG_CTL_ARCH}.%F';
    backup (current controlfile format='${TAG_CTL_ARCH}.%d_%t_%s_%p' tag='${TAG_CTL_ARCH}.${START_TIMESTAPM}');
    release channel c1;
    }"
}

# function backup_spfile
backup_spfile () {
    # print sql function
    echo "run {
    configure controlfile autobackup format for device type sbt to '${FORMAT_CTL_ARCH}.%F';
    allocate channel s1 type '$DEVICE' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';
    configure controlfile autobackup format for device type sbt to '${TAG_CTL_ARCH}.%F';
    backup (spfile format='${FORMAT_SPF}.%d_%t_%s_%p' tag='${TAG_SPF}.${START_TIMESTAPM}');
    release channel s1;
    }"
}

# function db_shutdown
dbShutdown () {
printMsg
printMsg "Shutting down the database $1..."
# print command
echo "su - $ORA_USER -c \"
export ORACLE_SID=$1;
sqlplus '/ as sysdba' <<EOD
shutdown immediate;
startup restrict;
shutdown immediate;
startup mount;
EOD
\"
"
}

# function db_startup
dbStartup () {
printMsg
printMsg "Starting up the database $1..."
# print command
echo "su - $ORA_USER -c \"
export ORACLE_SID=$1;
sqlplus '/ as sysdba' <<EOD
alter database open;
EOD
\"
"
}

# function check_database_corruption
checkDatabaseCorruption () {
echo "su - $ORA_USER -s \"
    sqlplus /nolog <<EOD
connect / as sysdba
select * from v\$backup_corruption;
select * from v\$database_block_corruption;
EOD
\"
"
}

# function allocate channels
allocateChannels () {
    NUMBER_OF_CHANNELS=$1
    ALLOCATE_CHANNELS_TMP=${TMP_DIR}/$$.allocate_channels.tmp
    for i in $(seq 1 $NUMBER_OF_CHANNELS); do
        echo "allocate channel b${i} type '$DEVICE' maxpiecesize ${MAXPIECESIZE}G maxopenfiles $MAXOPENFILES parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';" >>$ALLOCATE_CHANNELS_TMP
    done
    cat $ALLOCATE_CHANNELS_TMP
    rm -f $ALLOCATE_CHANNELS_TMP
}

# function release channels
releaseChannels () {
    NUMBER_OF_CHANNELS=$1
    RELEASE_CHANNELS_TMP=${TMP_DIR}/$$.release_channels.tmp
    for i in $(seq 1 $NUMBER_OF_CHANNELS); do
        echo "release channel b${i};" >>$RELEASE_CHANNELS_TMP
    done
    cat $RELEASE_CHANNELS_TMP
    rm -f $RELEASE_CHANNELS_TMP
}

# function backup_db
backup_db () {
    ALLOCATE_CHANNELS=$(allocateChannels $CHANNELS)
    RELEASE_CHANNELS=$(releaseChannels $CHANNELS) 
    # print sql function
    echo "run {
    sql 'alter database backup controlfile to trace';
    $ALLOCATE_CHANNELS
    configure controlfile autobackup format for device type sbt to '${TAG_CTL}.%F';
    backup $COMPRESSION $BACKUP_TYPE filesperset=$FILESPERSET check logical 
    (database format='${BACKUP_TAG}.%d_%t_%s_%p' tag='${BACKUP_TAG}.${ORACLE_SID}.${START_TIMESTAPM}')
    plus archivelog format='${TAG_ARCH_BKP}.%d_%t_%s_%p' tag='${TAG_ARCH_BKP}.${ORACLE_SID}.${START_TIMESTAPM}' delete input;
    backup (current controlfile format='${TAG_CTL}.%d_%t_%s_%p' tag='${TAG_CTL}.${ORACLE_SID}.${START_TIMESTAPM}')
    (spfile format='${TAG_SPF}.%d_%t_%s_%p' tag='${TAG_SPF}.${ORACLE_SID}.$($TIMESTAPM)');
    $RELEASE_CHANNELS
    }"
}

