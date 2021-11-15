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