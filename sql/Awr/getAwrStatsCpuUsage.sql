set linesize 120
set pagesize 10000
set HEAD OFF
set FEEDBACK OFF
set COLSEP |
set HEADSEP OFF
SET TRIMPOOL ON
SPOOL &2
alter session set NLS_NUMERIC_CHARACTERS = '.,';
select 'hostname|instance|begin_snap|end_snap|snap_interval_ms|snap_date|vcpu|dbtime_min' from dual;
with interval_sec as (
SELECT b.dbid,b.instance_number,b.snap_id start_id,e.snap_id end_id, extract( day from e.end_interval_time-b.end_interval_time)*24*60*60*1000 + extract( hour from e.end_interval_time-b.end_interval_time)*60*60*1000 + extract( minute from e.end_interval_time-b.end_interval_time )*60*1000 + round(extract( second from e.end_interval_time-b.end_interval_time )*1000) total_milliseconds
FROM SYS.DBA_HIST_SNAPSHOT b,
	SYS.DBA_HIST_SNAPSHOT e
WHERE b.snap_id+1=e.snap_id AND
	b.instance_number=e.instance_number AND
	b.dbid=e.dbid
)  --                                                                                                                   vcpu                                                            db_time_awr_minutes
SELECT a.host_name||'|'||a.instance_name||'|'||s.snap_id||'|'||e.snap_id||'|'||i.total_milliseconds ||'|'||to_char(end_interval_time,'YYYYMMDD-HH24:MI')||'|'||Round(NVL((e.value - s.value),-1)/(1000*i.total_milliseconds),2)||'|'||Round(NVL((e.value - s.value),-1)/60/1000000,2)
FROM   
	SYS.DBA_HIST_SYS_TIME_MODEL s,
    SYS.DBA_HIST_SYS_TIME_MODEL e,
	SYS.DBA_HIST_SNAPSHOT sn,
	V$INSTANCE a,
	interval_sec i
WHERE  
	e.dbid = s.dbid AND
    e.instance_number = s.instance_number AND
	e.snap_id=s.snap_id+1 AND
    e.stat_name = 'DB CPU' AND
	e.instance_number=a.instance_number AND
    s.stat_id=e.stat_id AND
	sn.instance_number=s.instance_number AND
	sn.dbid=s.dbid AND
	sn.snap_id=e.snap_id AND
	i.start_id=s.snap_id AND
	i.end_id=e.snap_id AND
	i.instance_number=s.instance_number AND
    a.instance_name='&1'
	ORDER BY s.snap_id;
exit;
