set pagesize 10000
select distinct '!SysStatCpu|'||host_name||'|'||d.instance_name||'|'||n.stat_name||'|'||to_char(end_interval_time,'YYYY-MM-DD-HH24-MI-SS')||'|'||value
from WRH$_OSSTAT s
inner join WRH$_OSSTAT_NAME n on n.stat_id=s.stat_id
inner join WRM$_SNAPSHOT p on p.snap_id=s.snap_id
and p.instance_number=s.instance_number 
and p.dbid=s.dbid
inner join WRM$_DATABASE_INSTANCE d on p.instance_number=d.instance_number 
and p.dbid=d.dbid
and n.stat_name in ('BUSY_TIME','IDLE_TIME')
order by 1;