SELECT dbi.instance_name,max(round(pga.value/1048576,2)) as max_pga_MB
FROM sys.wrm$_database_instance dbi 
INNER JOIN sys.wrh$_pgastat pga ON dbi.dbid=pga.dbid AND dbi.instance_number=pga.instance_number
INNER JOIN SYS.WRM$_SNAPSHOT snp ON snp.dbid=pga.dbid AND snp.instance_number=pga.instance_number AND snp.snap_id=pga.snap_id 
AND pga.name='maximum PGA allocated'
group by dbi.instance_name
order by 1 asc;