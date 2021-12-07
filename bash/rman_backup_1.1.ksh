#!/usr/bin/ksh
##########################################################################################
# Script name:      rman_backup_1.1.ksh
# Description:      Rman Backup Script
# Authors:          BaaS Team - Brno, Czech Republic
#                   Milan Dufek <milan_dufek@cz.ibm.com>
# Version:          1.1.1 (27.04.2018)
# Supported OS:     AIX, Linux, (TODO: Solaris, HP-UX)
#
# Req. files:       rman_functions_1.1.ksh (functions libr)
#                   rman_backup.ini (default init file)
# Optional files:   rman_backup_INSTANCE.ini (init file for each instance)
#
# Script usage:     rman_backup.sh [ FUNCTION ] [ ORACLE_SID ] [ DELETE_OBSOLETE_RETENTION ]
#
##########################################################################################
# List of return codes:
# ----- GENERIC RETURN CODES -------------------------------------------------------------
readonly ERR_NO_INIT=10                  # 10 - No init or rman_function file found
readonly ERR_NO_INST_INIT=11             # 11 - No instance init file found (rman_backup_$ORACLE_SID.ini)
readonly ERR_INSUFF_ARGS=12              # 12 - Insufficient number of arguments
readonly ERR_NO_FNC_DEF=13               # 13 - Backup type not defined in rman functions
readonly ERR_WRONG_USER=14               # 14 - Script started under wrong UNIX user
readonly ERR_NO_INST_RUNNING=15          # 15 - No Oracle instance is running for $ORACLE_SID inst
readonly ERR_ALREADY_RUNNING=16          # 16 - Script is already running for $ORACLE_SID inst
readonly ERR_ORAENV=17                   # 17 - Unable to load . oraenv
readonly ERR_NO_VEEAM=18                # 18 - TSM opt file not found for $ORACLE_SID inst
readonly ERR_OFFLINE_IN_BU=19            # 19 - OFFLINE backup started in busness hours and denied
# ------ SPECIFIC DELETE OBSOLETE RETURN CODES -------------------------------------------
readonly ERR_LOWER_CFRKT=21              # 21 = Value of CONTROL_FILE_RECORD_KEEP_TIME in RMAN is lower that expected (delobs_days + EXTRA_RETENTION)
readonly ERR_LOWER_RETPOL=22             # 22 = Value of RETENTION POLICY TO RECOVERY in RMAN catalog is lower that expected (delobs_days + EXTRA_RETENTION)
readonly ERR_GET_API_FS=23               # 23 = Cannot determine number of API:ORACLE filespaces
readonly ERR_TSM_CLIENT=24               # 24 = Problem on TSM client side configuration
readonly ERR_GET_RMAN_BO=25              # 25 = Cannot get Rman backup object list
readonly ERR_OBS_TSM_DATA=26             # 26 = Obsolete TSM data found
readonly ERR_MORE_API_FS=27              # 27 = More than one API:ORACLE filespace found
readonly ERR_GET_SQLPLUS=28              # 28 = Cannot get information from sqlplus (e.g. control_record_keeptime)
# ------ SPECIFIC DB OPERATIONS RETURN CODES ---------------------------------------------
readonly ERR_DB_SHUTDOWN=30              # 30 - Problem during DB shutdown
readonly ERR_DB_STARTUP=31               # 31 - Problem during DB startup
################################-#########################################################

# print help
if [[ "$1" == "-info" || "$1" == "-help" ]]; then
    END_HELP=$(cat -n $0 | grep -E "\#-\#" | awk '{ print $1 }')
    head -$END_HELP $0
    exit 1
fi

# vars definition
LOGGING=true # write output to LOG
SCREEN=false # write output to screen

# DO NOT OVERWRITE any vars here! Edit only rman_backup.ini file!
readonly WORK_DIR=$(cd $(dirname $0); pwd -P)
readonly SCRIPT_VERSION=1.1
readonly RMAN_INIT=${WORK_DIR}/rman_backup.ini
readonly RMAN_FUNCTIONS=${WORK_DIR}/rman_functions_${SCRIPT_VERSION}.ksh
readonly BASENAME=rman_backup
UNIX_USER=root
LOG_DIR=/exploit/logs/tsm
OS=$(uname | tr "[:upper:]" "[:lower:]")
OFFLINE_BACKUP=false
ONOFF="ON"
EXECUTED_CMD="$WORK_DIR/$(basename $0) $*"

# log maintainance
[ ! -d $LOG_DIR ] && mkdir -p $LOG_DIR
LOG=${LOG_DIR}/$BASENAME.$2.$1.$(date '+%Y-%m-%d-%H%M%S').log
>$LOG

# load Rman_functions
if [[ -e $RMAN_FUNCTIONS && -e $RMAN_INIT ]]; then
    . $RMAN_FUNCTIONS
    if [ $? -eq 0 ]; then
        printMsg "Script version: ${BASENAME}_${SCRIPT_VERSION}.ksh"
        printMsg "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
        printMsg "Command executed: $EXECUTED_CMD"
        printMsg "Rman fucntions ($RMAN_FUNCTIONS) loaded"
        . $RMAN_INIT
        if [ $? -eq 0 ]; then
            printMsg "Init file ($RMAN_INIT) loaded"
        else
            printMsg "Init file ($RMAN_INIT) cannot be loaded"
            exitScript $ERR_NO_INIT
        fi
    else
        echo "Rman fucntions ($RMAN_FUNCTIONS) file cannot be loaded" >>$LOG
        exit $ERR_NO_INIT
    fi
else
    echo "Configuration file not found ($RMAN_FUNCTIONS or $RMAN_INIT)" >>$LOG
    exit $ERR_NO_INIT
fi

# cleanup logs
printMsg "Cleaning old logs..."
echo $1 | grep -q backup_archivelog
[ $? -eq 0 ] && BACKUP_LOG_RETENTION=$(( $BACKUP_LOG_RETENTION * 10 ))
ls -1pt $LOG_DIR/$BASENAME.$2.$1.*.log | grep -v '/$' | tail -n +$(( $BACKUP_LOG_RETENTION + 1 )) | xargs rm -f 2>>$LOG

# verify UNIX user
if [ "$(id | sed 's/[^(]*(//' | sed 's/).*//')" != "$UNIX_USER" ]; then
    printMsg "Only $UNIX_USER can run this script"
    exitScript $ERR_WRONG_USER
fi

# replace seq function if not available on system
seq 1 >/dev/null 2>&1 || alias seq=seqGen

# adapt environment for specific systems
if [ "$OS" == "sunos" ]; then
    alias grep=/usr/xpg4/bin/grep
fi
if [ "$OS" == "hp-ux" ]; then
    echo >/dev/null # TBD
fi

# check, parse and load arguments
if [ $# -lt 2 ]; then
    printMsg "Insufficient number of arguments (2)"
    printMsg "Script usage: $0 [FUNCTION] [ORACLE_SID]"
    printMsg "Check script usage: $0 --info"
    exitScript $ERR_INSUFF_ARGS
else
    FUNCTION=$1
    ORACLE_SID=$2
    # find Oracle version
    ORACLE_VERSION=$(cat /etc/oratab | grep -v "^[#\*]" | grep -w ${ORACLE_SID} | sed 's/.*[product|oracle]\/\([0-9][0-9]*[a-z]*\).*/\1/g')
    [ -z "$ORACLE_VERSION" ] && ORACLE_VERSION=UNKNOWN
    ORACLE_VERSION_SHORT=$(cat /etc/oratab | grep -v "^[#\*]" | grep -w ${ORACLE_SID} | sed 's/.*[product|oracle]\/\([0-9][0-9]*\).*/\1/g')
fi

echo $FUNCTION | grep -Eq "delete_obsolete|backup_archivelog_emergency"
if [ $? -eq 0 ]; then
    if [[ "$3" == "" || $(isValidNumber $3; echo $?) -ne 0 ]]; then
        printMsg "Insufficient number of arguments (3) or 3rd argument is not a valid number"
        printMsg "Check script usage: $0 --info"
        exitScript $ERR_INSUFF_ARGS
    else
        DELETE_OBSOLETE_RETENTION=$3
        RETENTION_OR_FSUSAGE=$3
    fi
fi

# load INSTANCE init file
RMAN_INSTNACE_INIT=${WORK_DIR}/rman_backup_${ORACLE_SID}.ini
if [ -e $RMAN_INSTNACE_INIT ]; then
    . $RMAN_INSTNACE_INIT
    if [ $? -eq 0 ]; then
        printMsg "Init file ($RMAN_INSTNACE_INIT) loaded"
    else
        printMsg "Configuration file cannot be loaded"
        exitScript $ERR_NO_INST_INIT
    fi
fi

# test if called backup type exists
grep -qwE "\# function $FUNCTION" $RMAN_FUNCTIONS
if [ $? -ne 0 ]; then
    printMsg "Rman function $FUNCTION is not defined in $RMAN_FUNCTIONS"
    exitScript $ERR_NO_FNC_DEF
fi

# parse arguments for backup function
echo $FUNCTION | grep -qE "^backup_db_...._[a-z]{6,7}$"
if [ $? -eq 0 ]; then
    # if OFFLINE set flags
    echo $FUNCTION | cut -d '_' -f 4 | grep -q offline
    if [ $? -eq 0 ]; then
        OFFLINE_BACKUP=true
        ONOFF="OFF"
    fi
    # set backup type & tag
    case $(echo $FUNCTION | cut -d '_' -f 3) in
        inc0)
            BACKUP_TYPE="incremental level = 0"
            BACKUP_TAG="${TAG_BDB}_${TAG_L0}_$ONOFF"
            [ ! -z "$FILESPERSET_IL0" ] && FILESPERSET=$FILESPERSET_IL0
            ;;
        inc1)
            # from version 10 there is a change of incrementla strategy
            if [ $ORACLE_VERSION_SHORT -ge 10 ]; then
                BACKUP_TYPE="incremental level = 1 cumulative"
            else
                BACKUP_TYPE="incremental level = 1"
            fi
            BACKUP_TAG="${TAG_BDB}_${TAG_L1}_$ONOFF"
            [ ! -z "$FILESPERSET_IL1" ] && FILESPERSET=$FILESPERSET_IL1
            ;;
        inc2)
            # from version 10 there is a change of incrementla strategy
            if [ $ORACLE_VERSION_SHORT -ge 10 ]; then
                BACKUP_TYPE="incremental level = 1"
            else
                BACKUP_TYPE="incremental level = 2"
            fi
            BACKUP_TAG="${TAG_BDB}_${TAG_L2}_$ONOFF"
            [ ! -z "$FILESPERSET_IL2" ] && FILESPERSET=$FILESPERSET_IL2
            ;;
        full)
            BACKUP_TYPE="full"
            BACKUP_TAG="${TAG_BDB}_${TAG_FULL}_$ONOFF"
            [ ! -z "$FILESPERSET_IL0" ] && FILESPERSET=$FILESPERSET_IL0
            ;;
        *)
            printMsg "Rman function $FUNCTION is not defined in $RMAN_FUNCTIONS"
            exitScript $ERR_NO_FNC_DEF
            ;;
    esac
    # set function to backup_db
    FUNCTION=backup_db
fi

# check if Oracle instnace is running and find the Oracle user and Oracle home
ps -ef | grep -w ora_pmon_$ORACLE_SID | grep -v grep 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
    ORA_USER=$(ps -ef | grep -w ora_pmon_$ORACLE_SID | grep -v grep | awk '{ print $1 }')
else
    printMsg "No Oracle instance running for ORACLE_SID $ORACLE_SID"
    exitScript $ERR_NO_INST_RUNNING
fi

# check optfile
if [ -f "${VEEAM_LIB_PATH}" ]; then
    TDPO_OPTFILE="${VEEAM_LIB_PATH}/tdpo_${ORACLE_SID}.opt"
else
    printMsg "TSM opt (${VEEAM_LIB_FOLDER}/tdpo_${ORACLE_SID}.opt) file not found"
    exitScript $ERR_NO_TSMOPT
fi

# check if script is already running
ls -1 $TMP_DIR | grep -q $BASENAME.$FUNCTION.*.${ORACLE_SID}.pid
if [ $? -eq 0 ]; then
    for pid in $(cat ${TMP_DIR}/$BASENAME.$FUNCTION.*.${ORACLE_SID}.pid | cut -d ':' -f 4); do
        ps -p $pid
        if [ $? -eq 0 ]; then
            printMsg "Running process related to rman backup for $ORACLE_SID instance found"
            printFile ${TMP_DIR}/$BASENAME.$FUNCTION.$pid.${ORACLE_SID}.pid
            exitScript $ERR_ALREADY_RUNNING
        else
            printMsg "Cleaning old PID files from unfinished backups..."
            rm -f ${TMP_DIR}/$BASENAME.$FUNCTION.$pid.${ORACLE_SID}.pid ${TMP_DIR}/$pid.*.* ${WORK_DIR}/$pid.*.*
        fi
    done
fi

# set Rman connection
if [[ -z "$RMAN_CATALOG" || "$RMAN_CATALOG" == "NOCATALOG" ]]; then
    RMAN_CATALOG=NOCATALOG
    RMAN_CONNECTION="rman target / nocatalog"
else
    RMAN_CONNECTION="rman target / rcvcat=${RMAN_CATALOG_USER}/${RMAN_CATALOG_PASS}@${RMAN_CATALOG}"
fi

# prepare Oracle environment to load
ORAENV="ORACLE_SID=$ORACLE_SID; ORAENV_ASK=NO; . oraenv -s; [ $? -ne 0 ] && echo \"Exiting with return code $ERR_ORAENV\" && exit $ERR_ORAENV"

# set compression if enabled in config
if [ "$RMAN_COMPRESSION" == "yes" ]; then
    COMPRESSION="as compressed backupset"
else
    COMPRESSION=""
fi

#-----------------------------------------------------------------------------------------
# Processing RMAN function
#-----------------------------------------------------------------------------------------
PIDFILE=${TMP_DIR}/$BASENAME.$FUNCTION.$$.${ORACLE_SID}.pid
echo "$UNIX_USER:$FUNCTION:$ORACLE_SID:$$:$(date '+%Y%m%d%H%M%S')" > $PIDFILE

# for OFFINE backup - shutdown the database
if $OFFLINE_BACKUP; then
    inBussinessHours $BUSINESS_HOURS_FROM $BUSINESS_HOURS_TO
    if [ $? -eq 0 ]; then
        printMsg "OFFLINE backup in business hours is denied!"
        exitScript $ERR_OFFLINE_IN_BU
    fi
    for i in 3 2 1; do
        printMsg "Offline backup for ${ORACLE_SID} will start in $i minutes! Use this command to abort it: kill $$"
        echo "Offline backup for ${ORACLE_SID} will start in $i minutes! Use this command to abort it: kill $$" | wall
        sleep 60
    done
    echo; echo
    # shutdown database
    DB_SHUTDOWN=$WORK_DIR/$$.dbShutdown.$ORACLE_SID.ksh
    dbShutdown $ORACLE_SID >$DB_SHUTDOWN
    chown $ORA_USER $DB_SHUTDOWN
    chmod 744 $DB_SHUTDOWN
    $DB_SHUTDOWN >>$LOG 2>&1
    if [ $? -eq 0 ]; then
        printMsg "Database shutted down"
        sleep 10
    else
        printMsg "Problem occured during database shutdown"
        exitScript $ERR_DB_SHUTDOWN
    fi
fi

# emergency archlog function
if [ "$FUNCTION" == "backup_archivelog_emergency" ]; then
    backup_archivelog_emergency
    exitScript $?
fi

# rman function START
printBackupInfo
printMsg "Beginning of RMAN function $FUNCTION: $(date '+%Y-%m-%d %H:%M:%S')"
printMsg
RMAN_SCRIPT=${TMP_DIR}/$$.$FUNCTION.$ORACLE_SID.sql
$FUNCTION | sed -e 's/^[ \t]*//' >$RMAN_SCRIPT
chown $ORA_USER $RMAN_SCRIPT
chmod 744 $RMAN_SCRIPT
su - $ORA_USER -c "$ORAENV; $RMAN_CONNECTION @$RMAN_SCRIPT" >>$LOG 2>&1
RMAN_RC=$?
rm -f $RMAN_SCRIPT $PIDFILE
printMsg
printMsg "End of RMAN function $FUNCTION: $(date '+%Y-%m-%d %H:%M:%S')"

# start-up the database
if $OFFLINE_BACKUP; then
    DB_STARTUP=$WORK_DIR/$$.dbStartup.$ORACLE_SID.ksh
    dbStartup $ORACLE_SID >$DB_STARTUP
    chown $ORA_USER $DB_STARTUP
    chmod 744 $DB_STARTUP
    $DB_STARTUP >>$LOG 2>&1
    if [ $? -eq 0 ]; then
        printMsg "Database started up succesfully"
    else
        printMsg "Problem occured during database startup. Retrying..."
        $DB_STARTUP >>$LOG 2>&1
        if [ $? -ne 0 ]; then
            printMsg "Problem occured during database startup"
            exitScript $ERR_DB_STARTUP
        fi
    fi
    rm -f $DB_STARTUP
fi

# verification after DELETE OBSOLETE
echo $FUNCTION | grep -q delete_obsolete
if [[ $? -eq 0 && $RMAN_RC -eq 0 ]]; then
    if [ "$RMAN_CATALOG" == "NOCATALOG" ]; then
        # cross-check value of control_file_record_keep_time on RMAN >= delete obsolete in days + EXTRA_RETENTION
        checkControlFileRecordKeeptime || exitScript $ERR_LOWER_CFRKT
    else
        # cross-check value of CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF XX DAYS if catalog is used >= delete obsolete in days + EXTRA_RETENTION
        checkRetentionPolicy || exitScript $ERR_LOWER_RETPOL
    fi
    # check of obsolete backup data on TSM delete obsolete days + EXTRA_RETENTION
    checkUndeletedBackups || exitScript $?
    # check if there are multiple filespaces for API:ORACLE under same TSM NODE
    [ "$CHECK_FILESPACES" == "yes" ] && checkFilespaces || exitScript $?
fi

# rman function END
printMsg
printMsg "$FUNCTION $BACKUP_TYPE finished for instance ${ORACLE_SID}"
printMsg "End time: $(date '+%Y-%m-%d %H:%M:%S')"

exitScript $RMAN_RC
