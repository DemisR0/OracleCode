-- oraGetAwrMaxIoReadsSnaps
-- Target: get the snaps for which there have been the maximum number of logical reads
-- Use AWR repo
col begin_interval_time format a30
set lines 160 pages 1000
col end_interval_time format a30
col stat_value format 9999999999999999
set colsep '|'
alter session set nls_date_format='DD-MON-YYYY';
with logical_reads_from_cache as (
SELECT  sysst.snap_id, sysst.instance_number, begin_interval_time ,end_interval_time ,  startup_time,
VALUE - lag (VALUE) OVER ( PARTITION BY  startup_time, sysst.instance_number
                ORDER BY begin_interval_time, startup_time, sysst.instance_number) stat_value,
EXTRACT (DAY    FROM (end_interval_time-begin_interval_time))*24*60*60+
            EXTRACT (HOUR   FROM (end_interval_time-begin_interval_time))*60*60+
            EXTRACT (MINUTE FROM (end_interval_time-begin_interval_time))*60+
            EXTRACT (SECOND FROM (end_interval_time-begin_interval_time)) DELTA
  FROM sys.wrh$_sysstat sysst , DBA_HIST_SNAPSHOT snaps
WHERE (sysst.dbid, sysst.stat_id) IN ( SELECT dbid, stat_id FROM sys.wrh$_stat_name WHERE  stat_name='physical reads' )
AND snaps.snap_id = sysst.snap_id
AND snaps.dbid =sysst.dbid
AND sysst.instance_number=snaps.instance_number
and begin_interval_time > sysdate-90
)
SELECT instance_number,
  to_char(end_interval_time,'DD/MM/YYYY HH24:MI'),
  stat_value
FROM logical_reads_from_cache
WHERE instance_number=1
ORDER BY 2;
