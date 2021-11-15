set linesize 120
set pagesize 50000
set HEAD OFF
set FEEDBACK OFF
set COLSEP |
set HEADSEP OFF
SET TRIMPOOL ON
COL instance_name FOR A20
COL snp_date FOR A25
COL rdb_written FOR 999999999 
COL 1 head "hostname|snap_id|database_id|instance_name|snap_date|snap_duration|redo_size_bytes_s"
WITH redo_size AS (
    SELECT ss.snap_id,dbi.host_name,
    dbi.instance_name,
    sn.dbid,
    dbi.instance_number,
    ss.stat_id,ss.value
    FROM WRH$_SYSSTAT ss 
    INNER JOIN WRM$_DATABASE_INSTANCE dbi ON dbi.dbid=ss.dbid 
    AND dbi.instance_number=ss.instance_number
    INNER JOIN WRH$_STAT_NAME sn ON sn.dbid = ss.dbid 
    AND sn.stat_id=ss.stat_id
    WHERE sn.stat_name='redo size'
    ORDER BY snap_id
),
snap_info as(
    SELECT snp.snap_id,
    snp.dbid, snp.instance_number,
    (EXTRACT (DAY FROM (END_INTERVAL_TIME-BEGIN_INTERVAL_TIME))*24*60*60+EXTRACT (HOUR FROM (END_INTERVAL_TIME-BEGIN_INTERVAL_TIME))*60*60+
    EXTRACT (MINUTE FROM (END_INTERVAL_TIME-BEGIN_INTERVAL_TIME))*60+EXTRACT (SECOND FROM (END_INTERVAL_TIME-BEGIN_INTERVAL_TIME))) as elapsed_sec,
    snp.END_INTERVAL_TIME
    FROM WRM$_SNAPSHOT snp
)
SELECT e.host_name||'|'||
    e.snap_id||'|'||
    e.dbid||'|'||
    e.instance_name||'|'||
    to_char(si.end_interval_time,'YYYYMMDD-HH24:MI')||'|'||
    round(si.elapsed_sec,0)||'|'||
    round((e.value-b.value)/(si.elapsed_sec),2)
FROM redo_size b
INNER JOIN redo_size e ON b.snap_id+1=e.snap_id
AND b.dbid=e.dbid
AND b.instance_number=e.instance_number
AND b.instance_name!='awr'
INNER JOIN snap_info si ON si.dbid=e.dbid
AND si.instance_number=e.instance_number
AND si.snap_id=b.snap_id
ORDER BY e.dbid,e.instance_name,e.snap_id ASC;