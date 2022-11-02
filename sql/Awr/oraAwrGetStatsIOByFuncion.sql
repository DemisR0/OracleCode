-- oraGetAwrMaxIoReadsSnaps
-- Target: get the snaps for which there have been the maximum number of logical reads
-- Use AWR rep
        alter session set nls_date_format = 'YYYY-MM-DD HH24:MI' ;
        alter session  set NLS_NUMERIC_CHARACTERS= '. ';
        alter session set nls_lang='AMERICAN';
        alter session set NLS_TERRITORY='AMERICA';
        set head off
        col begin_interval_time format a30
        set lines 300 pages 50000
        col end_interval_time format a30
        col stat_value format 9999999
        col host_name format a10
        col instance format a8
        col func format a20
        col small_reads_mb  format 99999
        col small_writes_mb format 99999
        col large_read_mb  format 99999
        col large_write_mb format 99999
        col small_read_reqs format 99999
        col small_write_reqs format 99999
        col large_read_reqs format 99999
        col large_write_reqs format 99999
        col delta format 999999
        set colsep ','
        select '||host_name,instance_number,snap_id,instance_name,date,io_func,small_reads_b,small_writes_b,large_read_b,large_write_b,small_read_reqs,small_write_reqs,large_read_reqs,large_write_reqs'
        from dual;
        alter session set nls_date_format='DD-MON-YYYY';
        with io_by_func as (
        select  snaps.dbid,sysst.snap_id, sysst.instance_number, begin_interval_time ,end_interval_time ,  startup_time, function_name,
        SMALL_READ_MEGABYTES - lag (SMALL_READ_MEGABYTES) over ( partition by  snaps.dbid,startup_time, sysst.instance_number, function_name 
                        order by sysst.snap_id,begin_interval_time) small_reads_mb,
        SMALL_WRITE_MEGABYTES - lag (SMALL_WRITE_MEGABYTES) over ( partition by  snaps.dbid,startup_time, sysst.instance_number, function_name 
                        order by sysst.snap_id,begin_interval_time) small_writes_mb,
        LARGE_READ_MEGABYTES - lag (LARGE_READ_MEGABYTES) over ( partition by  snaps.dbid,startup_time, sysst.instance_number, function_name 
                        order by sysst.snap_id,begin_interval_time) large_read_mb,
        LARGE_WRITE_MEGABYTES - lag (LARGE_WRITE_MEGABYTES) over ( partition by  snaps.dbid,startup_time, sysst.instance_number, function_name 
                        order by sysst.snap_id,begin_interval_time) large_write_mb,
        SMALL_READ_REQS - lag (SMALL_READ_REQS) over ( partition by  snaps.dbid,startup_time, sysst.instance_number, function_name 
                        order by sysst.snap_id,begin_interval_time) small_read_reqs,
        SMALL_WRITE_REQS - lag (SMALL_WRITE_REQS) over ( partition by  snaps.dbid,startup_time, sysst.instance_number, function_name 
                        order by sysst.snap_id,begin_interval_time) small_write_reqs,
        LARGE_READ_REQS - lag (LARGE_READ_REQS) over ( partition by  snaps.dbid,startup_time, sysst.instance_number, function_name 
                        order by sysst.snap_id,begin_interval_time) large_read_reqs,
        LARGE_WRITE_REQS - lag (LARGE_WRITE_REQS) over ( partition by  snaps.dbid,startup_time, sysst.instance_number, function_name 
                        order by sysst.snap_id,begin_interval_time) large_write_reqs,
        extract (DAY    from (end_interval_time-begin_interval_time))*24*60*60+
                extract (HOUR   from (end_interval_time-begin_interval_time))*60*60+
                extract (MINUTE from (end_interval_time-begin_interval_time))*60+
                extract (SECOND from (end_interval_time-begin_interval_time)) DELTA
        from DBA_HIST_IOSTAT_FUNCTION sysst , DBA_HIST_SNAPSHOT snaps
        where snaps.snap_id = sysst.snap_id
        and snaps.dbid =sysst.dbid
        and sysst.instance_number=snaps.instance_number
        and begin_interval_time > sysdate-30 -- Nb of days
        )
        select '|'||di.host_name||','||di.instance_number||','||io.snap_id||','||di.instance_name||','||to_char(io.end_interval_time,'YYYYMMDD HH24:MI')||','||io.function_name||','||
                round((small_reads_mb)*1024*1024/DELTA,0)||','||
                round((small_writes_mb)*1024*1024/DELTA,0)||','||   
                round((large_read_mb)*1024*1024/DELTA,0)||','||
                round((large_write_mb)*1024*1024/DELTA,0)||','||
                round((small_read_reqs)*1024*1024/DELTA,0)||','||
                round((small_write_reqs)*1024*1024/DELTA,0)||','||
                round((large_read_reqs)*1024*1024/DELTA,0)||','||
                round((large_write_reqs)*1024*1024/DELTA,0)
        from io_by_func io
        inner join DBA_HIST_DATABASE_INSTANCE di ON di.dbid=io.dbid
        AND di.instance_number=io.instance_number
        AND di.startup_time=io.startup_time
        where io.small_reads_mb is not NULL
        and io.small_writes_mb is not NULL
        and io.large_read_mb is not NULL
        and io.large_write_mb is not NULL
        and io.small_read_reqs is not NULL
        and io.small_write_reqs is not NULL
        and io.large_read_reqs is not NULL
        and io.large_write_reqs is not NULL;