WITH minMaxSnaps AS (
SELECT dbid,instance_number,startup_time,MIN(begin_interval_time) min_snap,MAX(end_interval_time) max_snap
    FROM [AWRCPY].[WRM$_SNAPSHOT]
    WHERE error_count = 0
    AND status = 0
    GROUP BY dbid,instance_number,startup_time
)
select host_name,instance_name,MAX(DATEDIFF(second,min_snap,max_snap))
FROM minMaxSnaps p
INNER JOIN [AWRCPY].[WRM$_DATABASE_INSTANCE] d ON p.instance_number=d.instance_number
AND p.dbid=d.dbid
group by host_name,instance_name
