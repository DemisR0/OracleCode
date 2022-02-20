rman target / log=rman_backup_on_disk.log <<EOF
RUN {
ALLOCATE CHANNEL VeeamAgentChannel1 DEVICE TYPE DISK
FORMAT '/backuporacle/DWH00I/RMAN_%I_%d_MLY_FULL_%T_%U.vab';
ALLOCATE CHANNEL VeeamAgentChannel2 DEVICE TYPE DISK
FORMAT '/backuporacle/DWH00I/RMAN_%I_%d_MLY_FULL_%T_%U.vab';
ALLOCATE CHANNEL VeeamAgentChannel3 DEVICE TYPE DISK
FORMAT '/backuporacle/DWH00I/RMAN_%I_%d_MLY_FULL_%T_%U.vab';
BACKUP DATABASE PLUS ARCHIVELOG KEEP UNTIL TIME = 'sysdate+92' TAG "MLY_FULL";
backup as copy current controlfile format '/backuporacle/DWH00I/dwhc00i.ctl'
}
EXIT;
EOF
