# gather system stats
# 0 * * * * /exploit/scripts/dba/shell/sysDstats.bash
# 0 1 * * * find /exploit/dstats -name dstat_*\.csv -mtime +30 -exec rm {} \;
# 0 1 * * * find /exploit/dstats -name dstat_*\.csv -mtime +1 -exe gz {} \;

todayStats=/exploit/dstats/dstat_`date +%Y%m%d`.csv
dstat -tcdngy --noheaders --noupdate -N eth1,eth0 300 11 | grep ':.*:' >> ${todayStats}

# find /exploit/dstats -name dstat_*\.csv -mtime +30 -exec rm {} \;
# find /exploit/dstats -name dstat_*\.csv -mtime +1 -exe gz {} \;
