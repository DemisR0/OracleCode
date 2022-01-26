-- Parametres mémoire (non cachés) -- pas toujours vrai si mauvaise utilisation des parametres
WITH last_snap AS (
    SELECT i.dbid,i.host_name,i.instance_number,i.instance_name,max(snap_id) max_snap
    FROM [AWRCPY].[WRM$_SNAPSHOT] s
    INNER JOIN [AWRCPY].[WRM$_DATABASE_INSTANCE] i ON i.dbid=s.dbid
    AND i.instance_number=s.INSTANCE_NUMBER
    GROUP BY i.dbid,i.host_name,i.instance_number,i.instance_name
),
SGA AS (
SELECT HOST_NAME,INSTANCE_NAME, max(p.VALUE) max_sga --round(p.VALUE/1024/1024,0)
FROM [AWRCPY].[WRH$_PARAMETER] p
INNER JOIN [AWRCPY].[WRH$_PARAMETER_NAME] n ON p.dbid=n.DBID
AND  p.[PARAMETER_HASH]=n.[PARAMETER_HASH]
INNER JOIN last_snap l ON l.dbid=p.DBID
AND l.instance_number=p.instance_number
AND l.max_snap=p.snap_id
WHERE p.value IS NOT NULL
AND n.parameter_name in ('sga_max_size','sga_target')
GROUP BY HOST_NAME,INSTANCE_NAME
),
PGA AS (
SELECT HOST_NAME,INSTANCE_NAME,max(p.VALUE) max_pga --round(p.VALUE/1024/1024,0)
FROM [AWRCPY].[WRH$_PARAMETER] p
INNER JOIN [AWRCPY].[WRH$_PARAMETER_NAME] n ON p.dbid=n.DBID
AND  p.[PARAMETER_HASH]=n.[PARAMETER_HASH]
INNER JOIN last_snap l ON l.dbid=p.DBID
AND l.instance_number=p.instance_number
AND l.max_snap=p.snap_id
WHERE p.value IS NOT NULL
AND n.parameter_name in ('pga_aggregate_limit','pga_aggregate_target')
GROUP BY HOST_NAME,INSTANCE_NAME
)
SELECT p.HOST_NAME,p.INSTANCE_NAME,max_pga,max_sga
FROM PGA p
INNER JOIN SGA s ON s.host_name=p.host_name
AND p.instance_name=s.instance_name
ORDER BY 2,1,3;
