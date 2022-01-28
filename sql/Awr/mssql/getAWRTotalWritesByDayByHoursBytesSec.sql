-- All IO activities in IO_Bytes_sec
-- be carrefull if io are divided on different media to understand how is the repartition
-- especially if IO goes through networks

WITH raw_data AS (
SELECT  sysst.dbid, sysst.snap_id, sysst.instance_number, begin_interval_time ,end_interval_time ,  startup_time, stt_name.stat_name,
DATENAME(w,begin_interval_time) as wday, DATENAME(hh,begin_interval_time) as dhour,
sysst.VALUE - lag (sysst.VALUE) OVER ( PARTITION BY  sysst.dbid, sysst.instance_number, startup_time
                ORDER BY snaps.snap_id) as stat_value,
DATEDIFF(SECOND,BEGIN_INTERVAL_TIME,END_INTERVAL_TIME) as delta_t
  FROM [AWRCPY].[WRH$_SYSSTAT] sysst , [AWRCPY].[WRM$_SNAPSHOT] snaps, [AWRCPY].[WRH$_STAT_NAME] stt_name
WHERE stt_name.stat_name='physical write total bytes'
AND stt_name.dbid=snaps.DBID
AND stt_name.stat_id=sysst.STAT_ID
AND snaps.snap_id = sysst.snap_id
AND snaps.dbid =sysst.dbid
AND snaps.error_count < 1
AND sysst.instance_number=snaps.instance_number
)
SELECT rd.wday as day , cast(rd.dhour as int) as hour ,round(SUM(rd.stat_value/rd.delta_t),0) as Writes_Bytes_sec
FROM [AWRCPY].[WRM$_DATABASE_INSTANCE] dbi
JOIN raw_data rd ON dbi.dbid=rd.dbid
AND  dbi.instance_number=rd.instance_number
AND dbi.STARTUP_TIME=rd.STARTUP_TIME
WHERE dbi.INSTANCE_NAME in ('ANT1','ANT2','BFC1','BFC2','BIA1','BIA2','COD1','COD2','EAI1','EAI2','HOP1','HOP2','HR91','HR92','HRA1','HRA2','HYP1','HYP2','KFI1','KFI2')
GROUP BY wday,dhour
ORDER BY 1,2

-- ('ANT1','ANT2','BFC1','BFC2','BIA1,'BIA2','COD1','COD2','EAI1','EAI2','HOP1','HOP2','HR91','HR92','HRA1','HRA2','HYP1,'HYP2','KFI1','KFI2')
-- ('DSN1','DSN2','DWH1','DWH2','ETL1','ETL2','SAG1','SAG2','SGE1','SGE2')
-- ('FAC1','FAC2')
-- physical write bytes
-- physical read total bytes
-- physical write total bytes
