-- blocking DDL
set linesize 200
set pagesize 100
col time for a16
col event for a20
col status for a50
TTITLE COL 35 FORMAT 14 'BLOCKING EVENTS'
SELECT TO_CHAR(event_time, 'MM/DD HH24:MI:SS') time, commit_scn, current_scn, event, status FROM dba_logstdby_events ORDER BY event_time, commit_scn, current_scn; 

-- Status of synchronization

TTITLE COL 35 FORMAT 25 'LOGICAL STDBY SYNC STATUS'
SELECT APPLIED_SCN, to_char(APPLIED_TIME,'YYYY-MM-DD_HH24:MI:SS'), READ_SCN, to_char(READ_TIME,'YYYY-MM-DD_HH24:MI:SS'),NEWEST_SCN,  to_char(NEWEST_TIME,'YYYY-MM-DD_HH24:MI:SS') FROM DBA_LOGSTDBY_PROGRESS; 

set lines 300
COL NAME FORMAT A30
COL VALUE FORMAT A30
COL UNIT FORMAT A30
SELECT NAME, VALUE, UNIT FROM V$DATAGUARD_STATS;