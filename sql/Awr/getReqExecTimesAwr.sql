col STARTT format a17
set lines 160 pages 1000
col ENDT format a17
col snap_id for 999999
col instance_number for 99
col nb_exec for 999
alter session set nls_date_format = 'YYYYMMDD HH24:MI:SS';
select snaps.snap_id, snaps.instance_number as intance,sqlstt.PLAN_HASH_VALUE as plan_hash,OPTIMIZER_COST as cost, to_char(begin_interval_time,'YYYYMMDD HH24:MI:SS') STARTT,to_char(end_interval_time,'YYYYMMDD HH24:MI:SS') ENDT,EXECUTIONS_DELTA as nb_exec,DISK_READS_DELTA as dsk_reads,SORTS_DELTA as SORTS,ROWS_PROCESSED_DELTA NROWS_PROC,CPU_TIME_DELTA as cpu,round(ELAPSED_TIME_DELTA/(1000*1000*EXECUTIONS_DELTA),0) tps_by_exec
from DBA_HIST_SQLSTAT sqlstt join DBA_HIST_SNAPSHOT snaps
on sqlstt.dbid=snaps.dbid and sqlstt.snap_id=snaps.snap_id
and sql_id='14mq1014fugbb'
and EXECUTIONS_DELTA>0
where snaps.INSTANCE_NUMBER=1
order by snaps.snap_id asc;


--- toad
col STARTT format a17
set lines 160 pages 1000
col ENDT format a8
col snap_id for 999999
col instance_number for 99
col instance_number for 99
col sqlpro for a5
col inst for 9
col sum_ex for 9
-- sql_id
select to_char(snaps.begin_interval_time,'YYYYMMDD HH24:MI:SS') STARTT,to_char(snaps.end_interval_time,'HH24:MI:SS') ENDT,
snaps.snap_id, snaps.instance_number inst,plan_hash_value,sql_profile as sqlpro,sum(executions_delta) sum_ex,
round(sum(rows_processed_delta)/(case when sum(executions_delta) =0 then 1 else sum(executions_delta) end),2) avg_rows_per_ex,
round(sum(disk_reads_delta)/(sum(executions_delta) + .0001),2) avg_phyio_per_ex,
round(sum(buffer_gets_delta)/(sum(executions_delta) + .0001),2) avg_lio_per_ex,
round(sum(cpu_time_delta)/1000000/(case when sum(executions_delta) =0 then 1 else sum(executions_delta) end),2) avg_ctime_p_ex_secs,
round(sum(elapsed_time_delta)/1000000/(case when sum(executions_delta) =0 then 1 else sum(executions_delta) end),2) avg_etime_p_ex_secs
from dba_hist_sqlstat sqlstt join DBA_HIST_SNAPSHOT snaps
 on sqlstt.dbid=snaps.dbid and sqlstt.snap_id=snaps.snap_id
 where sql_id='1wtgfr09pj7tj'
 group by snaps.begin_interval_time,snaps.end_interval_time,snaps.snap_id,snaps.instance_number,sql_id,plan_hash_value, sql_profile
 order by snap_id;



 --- toad
 col STARTT format a17
 set lines 160 pages 1000
 col ENDT format a8
 col snap_id for 999999
 col instance_number for 99
 col instance_number for 99
 col avg_fetch_per_ex for 9999999999
 col sqlpro for a5
 col inst for 9
 col sum_ex for 9
 -- sql_id
 select to_char(snaps.begin_interval_time,'MMDD HH24:MI:SS') STARTT,to_char(snaps.end_interval_time,'HH24:MI:SS') ENDT,
 snaps.snap_id as endsnp,optimizer_cost as cost,plan_hash_value as plan_hash,sum(executions_delta) sum_ex,
 round(sum(PHYSICAL_READ_BYTES_DELTA/1024/1024)/(case when sum(executions_delta) =0 then 1 else sum(executions_delta) end),2) avg_rds_byt_per_ex,
 round(sum(FETCHES_DELTA)/(sum(executions_delta) + .0001),2) avg_fetch_per_ex,
 round(sum(CELL_UNCOMPRESSED_BYTES_DELTA)/(sum(executions_delta) + .0001),2) avg_cell_per_ex,
 round(sum(cpu_time_delta)/1000000/(case when sum(executions_delta) =0 then 1 else sum(executions_delta) end),2) avg_ctime_secs,
 round(sum(elapsed_time_delta)/1000000/(case when sum(executions_delta) =0 then 1 else sum(executions_delta) end),2) avg_etime_secs
 from dba_hist_sqlstat sqlstt join DBA_HIST_SNAPSHOT snaps
  on sqlstt.dbid=snaps.dbid and sqlstt.snap_id=snaps.snap_id
  where sql_id='417qxu38rr7jc'
  and snaps.instance_number=1
  group by snaps.begin_interval_time,optimizer_cost,snaps.end_interval_time,snaps.snap_id,snaps.instance_number,sql_id,plan_hash_value, sql_profile
  order by snaps.snap_id;
