# FJ
# connexion au repository awr et plot de la consommation cpu pour une base

# install.packages("RJDBC")
#  install.packages("rJava")
# install.packages("ROracle")
#R.Version()

require(RODBC)
library(rJava)
library(RODBC)
Sys.setenv(JAVA_HOME='C:/app/oracle/Client21c/jdk')

dbconn  <- odbcConnect("oraanalysis",uid = "system",
                   pwd = "putain2mot2pass")

dataframe <- sqlQuery(dbconn, "
SELECT  sysst.snap_id,sysst.dbid,snaps.startup_time,sysst.instance_number, begin_interval_time ,end_interval_time,
VALUE - lag (VALUE) OVER ( PARTITION BY  sysst.dbid, sysst.instance_number,snaps.startup_time,sysst.stat_id ORDER BY sysst.snap_id) stat_value,
EXTRACT (DAY    FROM (end_interval_time-begin_interval_time))*24*60*60+
            EXTRACT (HOUR   FROM (end_interval_time-begin_interval_time))*60*60+
            EXTRACT (MINUTE FROM (end_interval_time-begin_interval_time))*60+
            EXTRACT (SECOND FROM (end_interval_time-begin_interval_time)) DELTA
FROM SYS.WRH$_SYS_TIME_MODEL sysst 
INNER JOIN SYS.WRH$_STAT_NAME n ON 
n.stat_id=sysst.stat_id
AND n.dbid=sysst.dbid
AND n.stat_name='DB CPU'
INNER JOIN SYS.WRM$_SNAPSHOT snaps
ON snaps.snap_id = sysst.snap_id
AND snaps.dbid = sysst.dbid
AND sysst.instance_number = snaps.instance_number
AND snaps.status=0
AND snaps.error_count=0
and begin_interval_time > sysdate-10")

head(dataframe)
odbcClose(dbconn)

library(dplyr)
library(dbplyr)
library(lubridate)
