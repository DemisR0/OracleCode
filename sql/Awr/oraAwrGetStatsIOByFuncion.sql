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
        col stat_value format 9999999999999999
        col host_name format a15
        col instance_name format a8
        col function_name format a20
        set colsep ','
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
        select '|'||di.instance_name, di.host_name, to_char(io.end_interval_time,'YYYYMMDD HH24:MI'),io.function_name,
                round((small_reads_mb)/DELTA,0) small_reads_mb,
                round((small_writes_mb)/DELTA,0) small_writes_mb,
                round((large_read_mb)/DELTA,0) large_read_mb,
                round((large_write_mb)/DELTA,0) large_write_mb,
                round((small_read_reqs)/DELTA,0) small_read_reqs,
                round((small_write_reqs)/DELTA,0) small_write_reqs,
                round((large_read_reqs)/DELTA,0) large_read_reqs,
                round((large_write_reqs)/DELTA,0) large_write_reqs
        from io_by_func io
        inner join SYS.WRM$_DATABASE_INSTANCE di ON di.dbid=io.dbid
        AND di.instance_number=io.instance_number
        AND di.startup_time=io.startup_time
        where io.small_reads_mb is not NULL
        and io.small_writes_mb is not NULL
        and io.large_read_mb is not NULL
        and io.large_write_mb is not NULL
        and io.small_read_reqs is not NULL
        and io.small_write_reqs is not NULL
        and io.large_read_reqs is not NULL
        and io.large_write_reqs is not NULL
        order by 3,4 asc;