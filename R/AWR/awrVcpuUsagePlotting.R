# FJ
# connexion au repository awr et plot de la consommation cpu pour une base

# install.packages("RODBC")
#  install.packages("rJava")
#R.Version()

require(RODBC)
library(rJava)
library(RODBC)
library(dplyr)
library(dbplyr)
library(lubridate)
library(ggplot2)

Sys.setenv(JAVA_HOME='C:/app/oracle/Client21c/jdk')

# Constantes
dbid = 783443023    # FAC=783443023  DWH=2282045280

# functions

dbconn  <- odbcConnect("oraanalysis",uid = "system",
                   pwd = "putain2mot2pass")

awrSysTimeModelCpu <- sqlQuery(dbconn, "
WITH cpu AS (
SELECT  sysst.snap_id,sysst.stat_id, sysst.dbid,snaps.startup_time,sysst.instance_number,di.instance_name, begin_interval_time ,end_interval_time,
VALUE - lag (VALUE) OVER ( PARTITION BY  sysst.dbid, sysst.instance_number,snaps.startup_time,sysst.stat_id ORDER BY sysst.snap_id) stat_value,
EXTRACT (DAY    FROM (end_interval_time-begin_interval_time))*24*60*60+
            EXTRACT (HOUR   FROM (end_interval_time-begin_interval_time))*60*60+
            EXTRACT (MINUTE FROM (end_interval_time-begin_interval_time))*60+
            EXTRACT (SECOND FROM (end_interval_time-begin_interval_time)) DELTA
FROM SYS.WRH$_SYS_TIME_MODEL sysst
INNER JOIN SYS.WRH$_STAT_NAME n
ON n.stat_id=sysst.stat_id
AND n.dbid=sysst.dbid
AND n.stat_name in ('DB CPU','background cpu time')
INNER JOIN SYS.WRM$_SNAPSHOT snaps
ON snaps.snap_id = sysst.snap_id
AND snaps.dbid = sysst.dbid
AND sysst.instance_number = snaps.instance_number
INNER JOIN SYS.WRM$_DATABASE_INSTANCE di
ON di.dbid=snaps.dbid
AND di.instance_number=snaps.instance_number
AND di.startup_time=snaps.startup_time
AND begin_interval_time > sysdate-90
),
fgbgcpu AS(
SELECT snap_id,dbid,instance_name,end_interval_time,stat_value fgcpu , lag (stat_value) over ( partition by dbid,instance_number,startup_time,snap_id order by stat_id) bgcpu, DELTA -- /round(DELTA*1000000/60,0),2) VCpuUsed
FROM cpu
)
SELECT snap_id,dbid,instance_name,end_interval_time,round((fgcpu+bgcpu)/(DELTA*1000000),2) Vcpu
FROM fgbgcpu
WHERE bgcpu IS NOT NULL")


awrSysTimeModelCpuNonaDf <- na.omit(awrSysTimeModelCpu)
head(awrSysTimeModelCpu)

Instbm1 = 'FAC1'
Instbm2 = 'FAC2'
Instam = 'FAC'

inst1BmDf <- awrSysTimeModelCpuNonaDf [awrSysTimeModelCpuNonaDf$INSTANCE_NAME == Instbm1,]
head(inst1BmDf)

inst2BmDf <- awrSysTimeModelCpuNonaDf [awrSysTimeModelCpuNonaDf$INSTANCE_NAME == Instbm2,]
head(inst2BmDf)

instAmDf <- awrSysTimeModelCpuNonaDf [awrSysTimeModelCpuNonaDf$INSTANCE_NAME == Instam,] %>%
  select (END_INTERVAL_TIME,VCPU)
head(instAmDf)

instAllBmDf <- inner_join(inst1BmDf,inst2BmDf,by = c('SNAP_ID', 'DBID')) %>% 
  select(SNAP_ID,DBID,END_INTERVAL_TIME.x,VCPU.x,VCPU.y) 

head(instAllBmDf)

instBmDf <- instAllBmDf %>%  mutate(VCPU = VCPU.x + VCPU.y) %>%
  select (END_INTERVAL_TIME.x,VCPU) %>%  
  rename(END_INTERVAL_TIME= END_INTERVAL_TIME.x)


head(instBmDf,20)
instAllDf <- union(instBmDf,instAmDf)

ggplot(data=instAllDf,aes(x=END_INTERVAL_TIME, y=VCPU))	+ 
  geom_line(colour = "blue") +
  scale_x_datetime(date_breaks = "1 week") +
  geom_smooth(se = FALSE) +
  labs(x = "Date", y = "nb Vcpu", colour = "Colour\nlegend")
odbcClose(dbconn)


