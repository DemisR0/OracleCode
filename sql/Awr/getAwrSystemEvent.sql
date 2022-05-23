col begin_interval_time format a30
set lines 160 pages 1000
col end_interval_time format a30
set colsep '|'
col instance_number for 99
col snap_id for 99999

alter session set nls_date_format='YYYYMMDDHH24MI';
SELECT  sysst.snap_id, to_char(begin_interval_time,'YYYYMMDDHH24MI') ,to_char(end_interval_time,'YYYYMMDDHH24MI') , to_char(startup_time,'YYYYMMDDHH24MI'),
TOTAL_WAITS - lag (TOTAL_WAITS) OVER ( PARTITION BY  startup_time,sysst.dbid, sysst.instance_number
                ORDER BY sysst.snap_id) waits,
TIME_WAITED_MICRO - lag (TIME_WAITED_MICRO) OVER ( PARTITION BY  startup_time,sysst.dbid, sysst.instance_number
                                ORDER BY sysst.snap_id) timewt,
EXTRACT (DAY FROM (end_interval_time-begin_interval_time))*24*60*60+
            EXTRACT (HOUR   FROM (end_interval_time-begin_interval_time))*60*60+
            EXTRACT (MINUTE FROM (end_interval_time-begin_interval_time))*60+
            EXTRACT (SECOND FROM (end_interval_time-begin_interval_time)) DELTA
  FROM  WRH$_SYSTEM_EVENT sysst , DBA_HIST_SNAPSHOT snaps
WHERE (sysst.dbid, sysst.event_id) IN ( SELECT dbid, event_id FROM WRH$_EVENT_NAME  WHERE  event_name='direct path read' )
AND snaps.snap_id = sysst.snap_id
AND snaps.dbid =sysst.dbid
AND sysst.instance_number=snaps.instance_number
and begin_interval_time > sysdate-3



--  WRH$_SYSTEM_EVENT, WRH$_EVENT_NAME
