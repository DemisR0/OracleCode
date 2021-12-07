-- create a user and load from dump file to current database
-- require dump file uname
-- for i in `ls *.dmp | cut -d _ -f 3 | cut -d \. -f 1`; do  sqlplus / as sysdba @impawr.sql $i; done

create user AWR_TRN identified by "temppwd$"
default tablespace AWR
temporary tablespace TEMP;
grant create session to AWR_TRN;
grant unlimited tablespace to AWR_TRN;
grant read, write on directory DATA_PUMP_DIR to AWR_TRN;

variable schname varchar2(128);
exec :schname := 'AWR_TRN';
variable dmpfile varchar2(128);
exec :dmpfile := 'expdp_AWRsnaps_&1';
variable dmpdir varchar2(128);
exec :dmpdir := 'DATA_PUMP_DIR';

exec dbms_swrf_internal.awr_load(schname  => :schname, dmpfile  => :dmpfile,dmpdir   => :dmpdir);

DECLARE
        ldbid AWR_TRN.WRM$_DATABASE_INSTANCE.dbid%TYPE;
BEGIN
        select distinct(dbid) INTO ldbid from AWR_TRN.WRM$_DATABASE_INSTANCE;
        dbms_swrf_internal.move_to_awr(schname => :schname,new_dbid => ldbid);
END;
/
