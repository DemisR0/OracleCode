import tmux4sql
import os
import libtmux  # xserssion managemenr
from datetime import datetime # for session names individualisation
import time
import logging
# require ptpyt

"""
  MAIN
  V0 : monosession
"""

# Parameters
socks5 = '129.39.133.102'
wallixKOP = '15.1.92.188'
wallixKAz = '15.1.92.247'
serverName = wallixKAz
oracleServer = 'vml0dtbora000'
customer = 'korian'
sudoUser = 'oracle'

scriptCpu='oraAwrCpuStatsAllDb.bash'
scriptChgAwr='oraChgAwrParamAllDb.bash'
BashScriptPath='/mnt/c/oracle/OracleCode/python/autoBash/Scripts/' # \\ so \ is not seen as special
scriptName=scriptCpu

# Other variables
sessionBName = customer + '_ssh'

sessionName = tmux4sql.getTmuxSession(sessionBName)

tUserPass = tmux4sql.readPwd(customer,'ssh',serverName)
tmux4sql.connectSsh(sessionName,serverName,tUserPass[0],tUserPass[1],socks5)
tmux4sql.tmuxClear(sessionName)

wUserPass = tmux4sql.readPwd(customer,'wallix',oracleServer)
if not tmux4sql.wallixSelection(sessionName,oracleServer,wUserPass[0],wUserPass[1]):
    logging.error('wallixSelection: Unable to select a server')

if tmux4sql.sudo(sessionName,sudoUser) != True :
    logging.error('sudo : Unable to sudo as ' + sudoUser)

os.system('tmux set-option history-limit 500000')
#getMultiOraData(sessionName,BashScriptPath + scriptName)
tmux4sql.getMultiOraData(sessionName,BashScriptPath + scriptName)
tmux4sql.parseOutput(sessionName,'/mnt/c/temp' + sessionName + '.csv','|')
