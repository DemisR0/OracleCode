# 30 01 * * * /exploit/logrotate-tsm/logrotate-tsm.sh >> /exploit/logrotate-tsm/logrotate-tsm.log 2>&1
# delete all gz files older that 30 days

/bin/find /var/tsm/logs -type f -name "tsm_archive.*.log.gz"  -mtime +31 | while read LOG_FILE
  do
    date
    rm -f "$LOG_FILE"
    echo "RC=$?"
  done

# compress log files older that 14 days

/bin/find /var/tsm/logs -type f -name "tsm_archive.*.log"  -mtime +15 | while read LOG_FILE
  do
    date
    gzip -9 "$LOG_FILE"
    echo "RC=$?"
  done

exit