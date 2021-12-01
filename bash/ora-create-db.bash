

export ORACLE_SID=$1
export DOMAIN_NAME=
export CHARS=$3
export ${DATAFOLDER}
export ${RECOFOLDER}

mkdir -p /u04

dbca -silent -createDatabase                \
-templateName Transaction_Processing.dbc    \
-characterSet=${CHARS}                      \
-databaseConfigType SINGLE                  \
-gdbname ${ORACLE_SID}                      \
-instanceName ${ORACLE_SID}                 \
-databaseType OLTP                          \
-datafileDestination ${DATAFOLDER}/$ORACLE_SID} \
-enableArchive true                         \
-memoryMgmtType AUTO                        \
-totalMemory 1G                             \
-recoveryAreaDestination ${RECOFOLDER}/${ORACLE_SID} \
-redoLogFileSize 100M                       \
-storageType FS                             \
-useOMF true
