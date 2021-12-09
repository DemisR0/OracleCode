RED="\[$(tput setaf 1)\]" # prod
GREEN="\[$(tput setaf 2)\]" # non prod

export PROMPT_COMMAND='PS1="${RED}${HOSTNAME}:PRODUCTION:${LOGNAME}-${ORACLE_SID}> ";'

alias ll="ls -lhA"
alias adf="df -Tha --total"
alias adu="du -ach | sort -h"
alias apf="ps -aux"

# optionel oracle
# User specific aliases and functions
export ORACLE_BASE='/u01/app/oracle'
alias ora11g="export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1; export PATH=$PATH:/u01/app/oracle/product/11.2.0/dbhome_1/bin:/u01/app/oracle/product/11.2.0/dbhome_1/jdk/bin; expor
t LD_LIBRARY_PATH=/u01/app/oracle/product/11.2.0/dbhome_1/lib: export JAVA_HOME=/u01/app/oracle/product/11.2.0/dbhome_1/jdk"
alias ora121="export ORACLE_HOME=/u01/app/oracle/product/12.1.0/dbhome_1; export PATH=$PATH:/u01/app/oracle/product/12.1.0/dbhome_1/bin:/u01/app/oracle/product/12.1.0/dbhome_1/jdk/bin; expor
t LD_LIBRARY_PATH=/u01/app/oracle/product/12.1.0/dbhome_1/lib "
alias ora122="export ORACLE_HOME=/u01/app/oracle/product/12.2.0/dbhome_1; export PATH=$PATH:/u01/app/oracle/product/12.2.0/dbhome_1/bin:/u01/app/oracle/product/12.2.0/dbhome_1/jdk/bin; expor
t LD_LIBRARY_PATH=/u01/app/oracle/product/12.2.0/dbhome_1/lib "
alias ora19="export ORACLE_HOME=/u01/app/oracle/product/19/dbhome_1; export PATH=$PATH:/u01/app/oracle/product/19/dbhome_1/bin:/u01/app/oracle/product/19/dbhome_1/jdk/bin; export LD_LIBRARY_
PATH=/u01/app/oracle/product/19/dbhome_1/lib "
alias grid="export ORACLE_HOME=/u01/app/oracle/product/21/grid; export PATH=$PATH:/u01/app/oracle/product/21/grid/bin:/u01/app/oracle/product/21/grid/jdk/bin; export LD_LIBRARY_PATH=/u01/app
/oracle/product/21/grid/lib "
alias diags="cd /u01/app/oracle/diag/rdbms"
alias admins="cd /u01/app/oracle/admin/"

/exploit/scripts/dba/shell/oraSetInstanceAlias.bash
