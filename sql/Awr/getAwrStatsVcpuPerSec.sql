## fonctionne uniquement sur mono instance_name
## PB de redondance de l'instance name par rapport au dbid et a l' instance_number
-- Uniquement avec dbid instance_name startup_time pour eviter tout melange au niveau des instances qui partageraient le meme dbid et instance_name
-- retour en CPU/sec
col begin_interval_time format a30
set lines 160 pages 50000
col end_interval_time format a30
col begin_interval_time for a25
col end_interval_time for a25
col startup_time for a25
col instance_number for 99
set colsep ','
col host_name for a14
alter session set NLS_NUMERIC_CHARACTERS = ". ";
alter session set ALTER SESSION SET NLS_LANGUAGE= 'AMERICAN' NLS_TERRITORY= 'AMERICA';
alter session set nls_date_format='DD-MON-YYYY';

-- retour en CPU/sec -- séparaé par instance

WITH cpu AS (
SELECT  sysst.snap_id,sysst.stat_id, di.host_name, sysst.dbid,snaps.startup_time,sysst.instance_number,di.instance_name, begin_interval_time ,end_interval_time,
VALUE - lag (VALUE) OVER ( PARTITION BY  sysst.dbid,di.host_name, sysst.instance_number,snaps.startup_time,sysst.stat_id ORDER BY sysst.snap_id) stat_value,
EXTRACT (DAY    FROM (end_interval_time-begin_interval_time))*24*60*60+
            EXTRACT (HOUR   FROM (end_interval_time-begin_interval_time))*60*60+
            EXTRACT (MINUTE FROM (end_interval_time-begin_interval_time))*60+
            EXTRACT (SECOND FROM (end_interval_time-begin_interval_time)) DELTA
FROM SYS.WRH$_SYS_TIME_MODEL sysst
INNER JOIN SYS.WRH$_STAT_NAME n
ON n.stat_id=sysst.stat_id
AND n.dbid=sysst.dbid
AND n.stat_name in ('DB CPU','background cpu time')
INNER JOIN SYS.WRM$_SNAPSHOT snaps
ON snaps.snap_id = sysst.snap_id
AND snaps.dbid = sysst.dbid
AND sysst.instance_number = snaps.instance_number
INNER JOIN SYS.WRM$_DATABASE_INSTANCE di
ON di.dbid=snaps.dbid
AND di.instance_number=snaps.instance_number
AND di.startup_time=snaps.startup_time
AND begin_interval_time > sysdate-300
AND ERROR_COUNT<1
),
fgbgcpu AS(
SELECT snap_id,instance_name,cpu.instance_number,host_name,end_interval_time,stat_value fgcpu , lag (stat_value) over ( partition by dbid,instance_number,startup_time,snap_id order by stat_id) bgcpu, DELTA -- /round(DELTA*1000000/60,0),2) VCpuUsed
FROM cpu
)
SELECT 'krn',fgbgcpu.host_name,fgbgcpu.instance_number,snap_id,i.instance_name,to_char(end_interval_time,'YYYY-MM-DD HH24:MI'),round((fgcpu+bgcpu)*1.1/(DELTA*1000000),2) Vcpu_mnh
FROM fgbgcpu,v$instance i
WHERE bgcpu IS NOT NULL
ORDER BY snap_id ASC;

-- retour en min CPU pour X mn durée du report ajout background cpu pour se rapprocher des stats awr

WITH cpu AS (
SELECT  sysst.snap_id,sysst.stat_id, sysst.dbid,snaps.startup_time,sysst.instance_number,di.instance_name, begin_interval_time ,end_interval_time,
VALUE - lag (VALUE) OVER ( PARTITION BY  sysst.dbid, sysst.instance_number,snaps.startup_time,sysst.stat_id ORDER BY sysst.snap_id) stat_value,
EXTRACT (DAY    FROM (end_interval_time-begin_interval_time))*24*60*60+
            EXTRACT (HOUR   FROM (end_interval_time-begin_interval_time))*60*60+
            EXTRACT (MINUTE FROM (end_interval_time-begin_interval_time))*60+
            EXTRACT (SECOND FROM (end_interval_time-begin_interval_time)) DELTA
FROM SYS.WRH$_SYS_TIME_MODEL sysst
INNER JOIN SYS.WRH$_STAT_NAME n
ON n.stat_id=sysst.stat_id
AND n.dbid=sysst.dbid
AND n.stat_name in ('DB CPU','background cpu time')
INNER JOIN SYS.WRM$_SNAPSHOT snaps
ON snaps.snap_id = sysst.snap_id
AND snaps.dbid = sysst.dbid
AND sysst.instance_number = snaps.instance_number
INNER JOIN SYS.WRM$_DATABASE_INSTANCE di
ON di.dbid=snaps.dbid
AND di.instance_number=snaps.instance_number
AND di.startup_time=snaps.startup_time
AND begin_interval_time > sysdate-7
AND ERROR_COUNT<1
),
fgbgcpu AS(
SELECT snap_id,instance_name,end_interval_time,stat_value fgcpu , lag (stat_value) over ( partition by dbid,instance_number,startup_time,snap_id order by stat_id) bgcpu, DELTA -- /round(DELTA*1000000/60,0),2) VCpuUsed
FROM cpu
)
SELECT 'krn',host_name,snap_id,instance_name,end_interval_time,round((fgcpu+bgcpu)/(DELTA*1000000/60),2) Vcpu_mnh
FROM fgbgcpu,v$instance
WHERE bgcpu IS NOT NULL;
