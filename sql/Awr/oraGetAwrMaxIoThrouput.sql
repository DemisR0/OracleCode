-- oraGetAwrMaxIoReadsSnaps
-- Target: get the snaps for which there have been the maximum number of logical reads
-- Use AWR repo
alter session  set NLS_NUMERIC_CHARACTERS= '. ';
col begin_interval_time format a30
set lines 160 pages 1000
col end_interval_time format a30
col stat_value format 9999999999999999
col host_name format a25
col instance_name format a10
set colsep ','
alter session set nls_date_format='DD-MON-YYYY';
with phy_read_bytes as (
SELECT  snaps.dbid,sysst.snap_id, sysst.instance_number, begin_interval_time ,end_interval_time ,  startup_time,
VALUE - lag (VALUE) OVER ( PARTITION BY  snaps.dbid,startup_time, sysst.instance_number
                ORDER BY sysst.snap_id,begin_interval_time) readb_value,
EXTRACT (DAY    FROM (end_interval_time-begin_interval_time))*24*60*60+
            EXTRACT (HOUR   FROM (end_interval_time-begin_interval_time))*60*60+
            EXTRACT (MINUTE FROM (end_interval_time-begin_interval_time))*60+
            EXTRACT (SECOND FROM (end_interval_time-begin_interval_time)) DELTA
FROM sys.wrh$_sysstat sysst , DBA_HIST_SNAPSHOT snaps
WHERE (sysst.dbid, sysst.stat_id) IN ( SELECT dbid, stat_id FROM sys.wrh$_stat_name WHERE  stat_name='physical read total bytes' )
AND snaps.snap_id = sysst.snap_id
AND snaps.dbid =sysst.dbid
AND sysst.instance_number=snaps.instance_number
and begin_interval_time > sysdate-30 -- Nb of days
),
phy_write_bytes as (
SELECT  sysst.snap_id, sysst.instance_number, begin_interval_time ,end_interval_time ,  startup_time,
VALUE - lag (VALUE) OVER ( PARTITION BY  snaps.dbid,startup_time, sysst.instance_number
                ORDER BY sysst.snap_id,begin_interval_time) writeb_value
FROM sys.wrh$_sysstat sysst , DBA_HIST_SNAPSHOT snaps
WHERE (sysst.dbid, sysst.stat_id) IN ( SELECT dbid, stat_id FROM sys.wrh$_stat_name WHERE  stat_name='physical write total bytes' )
AND snaps.snap_id = sysst.snap_id
AND snaps.dbid =sysst.dbid
AND sysst.instance_number=snaps.instance_number
and begin_interval_time > sysdate-30 -- Nb of days
)
SELECT '|'||di.instance_name, di.host_name, to_char(rb.end_interval_time,'YYYYMMDD HH24:MI') SNP_DATE,round(readb_value/DELTA,0) readbytes_sec,round(writeb_value/DELTA,0) writebytes_sec, round((readb_value+writeb_value)/DELTA,2) io_bytes_sec
FROM phy_read_bytes rb
INNER JOIN phy_write_bytes wb ON rb.snap_id=wb.snap_id
AND rb.instance_number=wb.instance_number
AND rb.begin_interval_time=wb.begin_interval_time
AND rb.end_interval_time=wb.end_interval_time
AND rb.startup_time=wb.startup_time
INNER JOIN SYS.WRM$_DATABASE_INSTANCE di ON di.dbid=rb.dbid
AND di.instance_number=rb.instance_number
AND di.startup_time=rb.startup_time
ORDER BY 2 asc;
