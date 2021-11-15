-- to be used split by hour and week date
set linesize 80
set pagesize 4000
alter session set NLS_NUMERIC_CHARACTERS = '.,';
with snaps as (
    SELECT w.snap_id,w.startup_time,w.begin_interval_time, w.end_interval_time,m.instance_number,m.dbid,m.value
    FROM WRM$_SNAPSHOT w
    INNER JOIN WRH$_SYS_TIME_MODEL m ON m.snap_id=w.snap_id
    AND m.DBID=w.DBID 
    AND m.INSTANCE_NUMBER=w.INSTANCE_NUMBER
    INNER JOIN WRH$_STAT_NAME n ON n.dbid=w.dbid
    AND n.stat_id=m.stat_id
    AND n.stat_name = 'DB CPU'
    AND ERROR_COUNT<1
)
SELECT e.snap_id||','||d.host_name||','||d.instance_name||','||to_char(e.end_interval_time,'yyyy-MM-dd HH:mm:ss')||','||Round(NVL((e.value - s.value),-1)/(EXTRACT (DAY FROM (e.END_INTERVAL_TIME-e.BEGIN_INTERVAL_TIME))*24*60*60+EXTRACT (HOUR FROM (e.END_INTERVAL_TIME-e.BEGIN_INTERVAL_TIME))*60*60+
EXTRACT (MINUTE FROM (e.END_INTERVAL_TIME-e.BEGIN_INTERVAL_TIME))*60+
EXTRACT (SECOND FROM (e.END_INTERVAL_TIME-e.BEGIN_INTERVAL_TIME)))/1000000,2) cpu_by_instance_by_hour
FROM   snaps s,
       snaps e,
	   WRM$_DATABASE_INSTANCE d
 WHERE  e.dbid = s.dbid AND
       e.instance_number = s.instance_number AND
       e.snap_id=s.snap_id+1 AND
       e.startup_time=s.startup_time AND
	   d.dbid=s.dbid AND
	   d.instance_number=s.instance_number;