set pagesize 200
set linesize 200
col incremental_level for 9
col datasize_GB for 99999D99
col Bs_size_GB for 99999D99
TTITLE COL 35 FORMAT 25 'BACKUPSET LIST'
    SELECT d.session_recid, d.session_stamp,d.backup_type,d.incremental_level, 
    round(sum(original_input_bytes)/1024/1024/1024,2) datasize_GB,
    round(sum(output_bytes)/1024/1024/1024,2) Bs_size_GB, 
    to_char(min(d.start_time),'DD-MM-YYYY HH24') start_date,to_char(max(d.completion_time),'DD-MM-YYYY HH24') end_date
    FROM v$backup_set_details d
    WHERE d.backup_type!='L'
    GROUP BY d.session_recid, d.session_stamp,d.backup_type,d.incremental_level;