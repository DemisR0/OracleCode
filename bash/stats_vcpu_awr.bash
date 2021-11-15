set -x
BASE_FOLDER=/mnt/c/oracle
SQL_FOLDER=${BASE_FOLDER}/scripts/sql
CUSTOMER_NAME=$1
SCRIPT_NAME=$2
SCRIPT_PATH=${SQL_FOLDER}/${SCRIPT_NAME}
CUSTOMER_CFG=${BASE_FOLDER}/customers/${CUSTOMER_NAME}
TNS_ADMIN=${CUSTOMER_CFG}/tns
DBLIST=${CUSTOMER_CFG}/dbs
LOGIN=`cat ${CUSTOMER_CFG}/login`
START_DATE=`date +%F-%H-%M-%S`
LOG_PATH=${BASE_FOLDER}/logs/${CUSTOMER_NAME}_${SCRIPT_NAME}_${DB_INSTANCE}_${START_DATE}.log
export TNS_ADMIN
for instance_name in `cat ${DBLIST}/*stats` 
do
    echo ${instance_name}
    SPOOL_PATH=${BASE_FOLDER}/data/${CUSTOMER_NAME}/${CUSTOMER_NAME}_${SCRIPT_NAME}_${instance_name}_${START_DATE}
    sqlplus -s $LOGIN@${instance_name} @${SCRIPT_PATH} ${instance_name} $SPOOL_PATH.tmp 2>&1 > ${LOG_PATH}
    grep -v instance_name $SPOOL_PATH.tmp | grep -v '^$'> ${SPOOL_PATH}.csv
    rm $SPOOL_PATH.tmp
done