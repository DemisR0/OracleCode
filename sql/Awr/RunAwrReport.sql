DECLARE
  DBID           NUMBER;
  INST_ID        NUMBER;
  BID            NUMBER;
  EID            NUMBER;
  DB_UNIQUE_NAME VARCHAR2(30);
  STARTTIME      DATE;
  ENDTIME        DATE;
BEGIN
  STARTTIME := TO_DATE('&1', 'YYYY-MM-DD HH24:MI') - 1 / 24;
  ENDTIME   := TO_DATE('&2', 'YYYY-MM-DD HH24:MI');

  SELECT MIN(SNAP_ID), MAX(SNAP_ID)
    INTO BID, EID
    FROM DBA_HIST_SNAPSHOT DHS
   WHERE TRUNC(DHS.BEGIN_INTERVAL_TIME, 'HH24') >= TRUNC(STARTTIME, 'HH24')
     AND TRUNC(DHS.END_INTERVAL_TIME, 'HH24') <= TRUNC(ENDTIME, 'HH24');
  SELECT DBID, INST_ID, DB_UNIQUE_NAME
    INTO DBID, INST_ID, DB_UNIQUE_NAME
    FROM GV$DATABASE;

  FOR C1_REC IN (SELECT OUTPUT
                   FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(DBID,
                                                                       INST_ID,
                                                                       BID,
                                                                       EID))) LOOP
    DBMS_OUTPUT.PUT_LINE(C1_REC.OUTPUT);
  END LOOP;

END;
/
