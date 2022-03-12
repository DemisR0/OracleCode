## fonctionne uniquement sur mono instance_name
## PB de redondance de l'instance name par rapport au dbid et a l' instance_number

set pagesize 4000
with db_time as (
select ss.snap_id,dbi.instance_name,sn.dbid,dbi.instance_number,ss.value
from SYS.WRH$_SYS_TIME_MODEL ss
inner join SYS.WRM$_DATABASE_INSTANCE dbi on dbi.dbid=ss.dbid
and dbi.instance_number=ss.instance_number
inner join SYS.WRH$_STAT_NAME sn on sn.dbid = ss.dbid
and sn.stat_id=ss.stat_id
where sn.stat_name='DB CPU'
order by snap_id),
db_time_w_elapse as(
SELECT snp.snap_id,dbt.instance_name,(EXTRACT (DAY FROM (END_INTERVAL_TIME-BEGIN_INTERVAL_TIME))*24*60*60+EXTRACT (HOUR FROM (END_INTERVAL_TIME-BEGIN_INTERVAL_TIME))*60*60+
EXTRACT (MINUTE FROM (END_INTERVAL_TIME-BEGIN_INTERVAL_TIME))*60+
EXTRACT (SECOND FROM (END_INTERVAL_TIME-BEGIN_INTERVAL_TIME))) as elapsed,snp.END_INTERVAL_TIME,dbt.value
FROM SYS.WRM$_SNAPSHOT snp
INNER JOIN db_time dbt ON dbt.dbid=snp.dbid AND dbt.instance_number=snp.instance_number AND dbt.snap_id=snp.snap_id
),
cpu_per_sec_all_db as (select instance_name,end_interval_time as snp_date,elapsed,round((value-lag(value) over (partition by instance_name order by snap_id ))/(elapsed*1000000),2) as cpu_per_sec
from db_time_w_elapse)
select instance_name,to_char(snp_date,'YYYYMMDD-HH24MI') snap_date, cpu_per_sec
from cpu_per_sec_all_db
order by instance_name,snap_date asc;

-- Uniquement avec dbid instance_name startup_time pour eviter tout melange au niveau des instances qui partageraient le meme dbid et instance_name
-- retour en CPU/sec
col begin_interval_time format a30
set lines 160 pages 1000
col end_interval_time format a30
col begin_interval_time for a25
col end_interval_time for a25
col startup_time for a25
col instance_number for 99
set colsep '|'
alter session set nls_date_format='DD-MON-YYYY';

-- retour en CPU/sec

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
AND n.stat_name='DB CPU'
INNER JOIN SYS.WRM$_SNAPSHOT snaps
ON snaps.snap_id = sysst.snap_id
AND snaps.dbid = sysst.dbid
AND sysst.instance_number = snaps.instance_number
INNER JOIN SYS.WRM$_DATABASE_INSTANCE di
ON di.dbid=snaps.dbid
AND di.instance_number=snaps.instance_number
AND di.startup_time=snaps.startup_time
AND begin_interval_time > sysdate-10
)
SELECT snap_id,instance_name,end_interval_time,round(stat_value/(DELTA)/1000000,1)
FROM cpu
WHERE instance_name='FAC1'
ORDER BY snap_id;

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
AND begin_interval_time > sysdate-10
),
fgbgcpu AS(
SELECT snap_id,instance_name,end_interval_time,stat_value fgcpu , lag (stat_value) over ( partition by dbid,instance_number,startup_time,snap_id order by stat_id) bgcpu, DELTA -- /round(DELTA*1000000/60,0),2) VCpuUsed
FROM cpu
)
SELECT snap_id,instance_name,end_interval_time,round((fgcpu+bgcpu)/(DELTA*1000000/60),2) Vcpu
FROM fgbgcpu
WHERE bgcpu IS NOT NULL;
