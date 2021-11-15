#!/bin/ksh
#
# Script used to cleanup SYS.AUD$
#
SUCCESS=0
FAILURE=1
ORAENV="oraenv"
ORIGPATH=/usr/local/bin:$PATH
ORIGLD=$LD_LIBRARY_PATH
export PATH=$ORIGPATH

# Usage function.
f_usage(){
  echo "Usage: `basename $0` DAYS "
  echo "       DAYS = Number of days to keep audit records."
}

if [ $# -lt 1 ]; then
  f_usage
  exit $FAILURE
fi


# Function used to delete audit records.
f_audit(){
  sqlplus -s /nolog <<EOF
conn / as sysdba
delete from SYS.AUD$ where TIMESTAMP# < (sysdate-$DDAYS);
delete from SYS.AUD$ where NTIMESTAMP# < (sysdate-$DDAYS);
commit;
EOF
}

     DDAYS=$1

echo "`basename $0` Started `date`."


# Check for the oratab file.
if [ -f /var/opt/oracle/oratab ]; then
  ORATAB=/var/opt/oracle/oratab
elif [ -f /etc/oratab ]; then
  ORATAB=/etc/oratab
else
  echo "ERROR: Could not find oratab file."
  exit $FAILURE
fi

# Build list of distinct Oracle Home directories.
OH=`egrep -i ":Y|:N" $ORATAB | grep -v "^#" | grep -v "\*" | cut -d":" -f2 | sort | uniq`

# Exit if there are not Oracle Home directories.
if [ -z "$OH" ]; then
  echo "No Oracle Home directories to clean."
  exit $SUCCESS
fi

# Get the list of running databases.
SIDS=`ps -e -o args | grep pmon | grep -v grep | awk -F_ '{print $3}' | sort`

# Gather information for each running database.
for ORACLE_SID in `echo $SIDS`
do

  # Set the Oracle environment.
  ORAENV_ASK=NO
  export ORACLE_SID
  . $ORAENV

  if [ $? -ne 0 ]; then
    echo "Could not set Oracle environment for $ORACLE_SID."
  else
    export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORIGLD

    ORAENV_ASK=YES

    echo "ORACLE_SID: $ORACLE_SID"

    # Delete audit records.
    DELAUDIT=`f_audit`

  fi
done

echo "`basename $0` Finished `date`."

exit

