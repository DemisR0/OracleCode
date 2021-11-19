# create aliases to set env for each oracle instance
  # /exploit/scripts/dba/shell/oraSetInstanceAlias.bash
for ORACLE_SID in `cat /etc/oratab | grep "^[A-Z]" | cut -f1 -d:`
do
  alias ${ORACLE_SID}="export ORAENV_ASK=NO; export ORACLE_SID=${ORACLE_SID};. .bashrc;. oraenv"
done
