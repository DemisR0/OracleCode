create table korian.awrVcpu (hostname varchar (25) not null, 
	instance varchar (25) not null, 
	begin_snap int not null, 
	end_snap int not null, 
	snap_interval_ms int not null, 
	snap_date varchar (25) not null, 
	vcpu float, 
	dbtime_min float
	primary key (hostname,instance,begin_snap,end_snap));

create table korian.awrRedoMo (hostname varchar (25) not null, 
	instance varchar (25) not null, 
	dbid bigint not null,
	end_snap int not null, 
	snap_date varchar(14) not null,
	snap_interval_s int not null, 
	redo_mo_s float, 
	primary key (hostname,instance,end_snap));  
