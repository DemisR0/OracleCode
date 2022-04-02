alter session set nls_date_format = 'YYYY-MM-DD HH24:MI' ;
set colsep ','
set head off
set linesize 200
col instance_name for a20
col end_interval_time for a19
set pagesize 0
WITH cpu AS (
SELECT  sysst.snap_id,sysst.stat_id, sysst.dbid,snaps.startup_time,sysst.instance_number,di.instance_name, begin_interval_time ,end_interval_time,
VALUE - lag (VALUE) OVER ( PARTITION BY  sysst.dbid, sysst.instance_number,snaps.startup_time,sysst.stat_id ORDER BY sysst.snap_id) stat_value,
EXTRACT (DAY    FROM (end_interval_time-begin_interval_time))*24*60*60+
            EXTRACT (HOUR   FROM (end_interval_time-begin_interval_time))*60*60+
            EXTRACT (MINUTE FROM (end_interval_time-begin_interval_time))*60+
            EXTRACT (SECOND FROM (end_interval_time-begin_interval_time)) DELTA
FROM SYS.WRH\$_SYS_TIME_MODEL sysst
INNER JOIN SYS.WRH\$_STAT_NAME n
ON n.stat_id=sysst.stat_id
AND n.dbid=sysst.dbid
AND n.stat_name in ('DB CPU','background cpu time')
INNER JOIN SYS.WRM\$_SNAPSHOT snaps
ON snaps.snap_id = sysst.snap_id
AND snaps.dbid = sysst.dbid
AND sysst.instance_number = snaps.instance_number
INNER JOIN SYS.WRM\$_DATABASE_INSTANCE di
ON di.dbid=snaps.dbid
AND di.instance_number=snaps.instance_number
AND di.startup_time=snaps.startup_time
AND begin_interval_time > sysdate-90
),
fgbgcpu AS(
SELECT snap_id,instance_name,end_interval_time,stat_value fgcpu , lag (stat_value) over ( partition by dbid,instance_number,startup_time,snap_id order by stat_id) bgcpu, DELTA -- /round(DELTA*1000000/60,0),2) VCpuUsed
FROM cpu
)
SELECT '|'||snap_id||','||instance_name||','||to_char(end_interval_time,'YYYY-MM-DD HH24:MI')||','||round((fgcpu+bgcpu)*1.1/(DELTA*1000000),2)
FROM fgbgcpu
WHERE bgcpu IS NOT NULL;
exit;
