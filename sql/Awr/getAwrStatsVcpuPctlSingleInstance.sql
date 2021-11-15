--  1VCORE=2VCPU
-- il faut prendre ne minutes pour la comparaison avec AWR report
alter session set NLS_NUMERIC_CHARACTERS = '.,';
with snaps as (
    SELECT w.snap_id,w.startup_time,w.begin_interval_time,w.end_interval_time,m.stat_id,m.instance_number,m.dbid,m.value
    FROM SYS.WRM$_SNAPSHOT w
    INNER JOIN WRH$_SYS_TIME_MODEL m ON m.snap_id=w.snap_id
),
time as (SELECT s.snap_id begin,e.snap_id end,Round(NVL((e.value - s.value),-1)/(EXTRACT (DAY FROM (e.END_INTERVAL_TIME-e.BEGIN_INTERVAL_TIME))*24*60*60+EXTRACT (HOUR FROM (e.END_INTERVAL_TIME-e.BEGIN_INTERVAL_TIME))*60*60+
EXTRACT (MINUTE FROM (e.END_INTERVAL_TIME-e.BEGIN_INTERVAL_TIME))*60+
EXTRACT (SECOND FROM (e.END_INTERVAL_TIME-e.BEGIN_INTERVAL_TIME)))/1000000,2) cpu
FROM   snaps s,
       snaps e,
	   SYS.WRM$_DATABASE_INSTANCE d,
       SYS.WRH$_STAT_NAME n
WHERE  e.dbid = s.dbid AND
       e.instance_number = s.instance_number AND
       n.stat_name = 'DB CPU' AND
       s.stat_id=n.stat_id AND
       e.snap_id=s.snap_id+1 AND
       e.startup_time=s.startup_time AND
       s.dbid=n.dbid AND
       e.stat_id = s.stat_id AND
	   d.dbid=s.dbid AND
	   d.instance_number=s.instance_number AND
	   d.instance_name='&1'
ORDER BY 1)
select '&&1'||','||round(max(cpu),2)||','||
    -- PERCENTILE_DISC(0.99) within group (order by cpu asc)/2 "99 pct/cores",
	PERCENTILE_DISC(0.99) within group (order by cpu asc)||','||
	PERCENTILE_DISC(0.98) within group (order by cpu asc)||','||
    PERCENTILE_DISC(0.95) within group (order by cpu asc)
from time;