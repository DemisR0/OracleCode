WITH redo_size AS (
    SELECT ss.snap_id,dbi.host_name,
    dbi.instance_name,
    sn.dbid,
    dbi.instance_number,
    ss.stat_id,ss.value
    FROM [AWRCPY].[WRH$_SYSSTAT] ss
    INNER JOIN [AWRCPY].[WRM$_DATABASE_INSTANCE] dbi ON dbi.dbid=ss.dbid
    AND dbi.instance_number=ss.instance_number
    INNER JOIN [AWRCPY].[WRH$_STAT_NAME] sn ON sn.dbid = ss.dbid
    AND sn.stat_id=ss.stat_id
    WHERE sn.stat_name='redo size'
),
snap_info as(
    SELECT snp.snap_id,
    snp.dbid, snp.instance_number,
    DATEDIFF(SECOND,BEGIN_INTERVAL_TIME,END_INTERVAL_TIME) as elapsed_sec,
    snp.END_INTERVAL_TIME
    FROM [AWRCPY].[WRM$_SNAPSHOT] snp
)
SELECT CONCAT(e.host_name,'|',
    e.snap_id,'|',
    e.dbid,'|',
    e.instance_name,'|',
    convert(VARCHAR,si.end_interval_time,20),'|',
    round(si.elapsed_sec,0),'|',
    round((e.value-b.value)/(si.elapsed_sec),2))
FROM redo_size b
INNER JOIN redo_size e ON b.snap_id+1=e.snap_id
AND b.dbid=e.dbid
AND b.instance_number=e.instance_number
AND b.instance_name!='awr'
INNER JOIN snap_info si ON si.dbid=e.dbid
AND si.instance_number=e.instance_number
AND si.snap_id=b.snap_id
ORDER BY e.dbid,e.instance_name,e.snap_id ASC;
