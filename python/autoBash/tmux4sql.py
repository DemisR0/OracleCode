import os
import libtmux  # xserssion managemenr
from datetime import datetime # for session names individualisation
import time
import logging
# require ptpython: pip install --user ptpython

def readPwd(customer,domain,srvName):
    """
    read password file $HOME/.pass and extract the first [username,password] matching the 3 parameters.
    return None if not found
    """
    fname='readPwdFile'
    filename='.pass'
    entry=customer + ':' + domain + ':' + srvName+':'
    filePath=os.path.expanduser('~') + '/' + filename

    if os.path.exists(filePath) == False:
        logging.error('~/.pass file does not exist')
        return False

    try:
        pwdFilePtr = open(filePath,'r')
    except Exception as diag:
        logging.error(diag.__class__.__name__,':','readPwdFile',':',diag)
        return False

    for line in pwdFilePtr:
        if line.find(entry) == 0:
            pwdFilePtr.close()
            return (line.split('\n')[0].split(entry)[1].split(':'))
    return True
## ------------------------
def dateTime():
    now = datetime.now()
    return now.strftime("%m%d%H%M%S")
## -----------------------
def connectSsh (sName,srvName,userName,password,socksServer = '',socksSrvPort = '1080'):
    """
    create an ssh session throught the windows pane provided
    """
    sshCommand='sshpass -p \''+password+'\' ssh "'+userName+'"@'+srvName
    if socksServer != '':
        sshCommand = sshCommand + ' -o "ProxyCommand=nc -X 5 -x ' + socksServer + ':' + socksSrvPort + ' %h %p"'
        print('tmux send-key -t ' + sName + ' \'' + sshCommand + '\' Enter')
        os.system('tmux send-key -t ' + sName + ' \'' + sshCommand + '\' Enter' )
        print(os.popen('tmux capture-pane -pS -3 -t ' + sName ).read())
        #os.system('tmux capture-pane -pS -100 -t ' + sName )
    time.sleep(5)
    return True
##-------------------------
def wallixSelection(sName,srvName,userName,password):
    """
    select server in wallix menu
    """
    lines = os.popen('tmux capture-pane -pS -100 -t ' + sName ).readlines()
    print(srvName + " " + userName + " " + password)
    for line in lines:
        print(line)
        if line.find(srvName) !=-1 :
            srvNum=line.split(" | ")[0].lstrip("| ")
            print('"'+srvNum+'"')
            os.system('tmux send-key -t ' + sName + ' ' + srvNum + ' Enter')
            time.sleep(5)
            os.system('tmux send-key -t ' + sName + ' \'' + userName + '\' Enter')
            time.sleep(5)
            os.system('tmux send-key -t ' + sName + ' \'' + password + '\' Enter')
            return True
    return False
##------------------------
def tmuxClear(sName):
    """
    clear terminal history
    """
    os.system('tmux send-key -t ' + sName + ' clear Enter')
    os.system('tmux clear-history')
    return True
##-----------------------
def sudo(sName,userName):
    if userName != '':
        os.system('tmux send-key -t ' + sName + ' \'sudo su - ' + userName + '\' Enter')
        tmuxClear(sName)
    else:
        return False
    os.system('tmux send-key -t ' + sName + ' whoami Enter')
    print(os.popen('tmux capture-pane -pS -3 -t ' + sName ).read())
    if os.popen('tmux capture-pane -pS -3 -t ' + sName ).read().find('\n' + userName) >= 0:
        return True
    return False
##-----------------------
def executeBash(sName,bashFile):
    """
    exec a loop to launch a sql over all started DB
    """
    try:
        bashFilePtr = open(bashFile,'r')
    except Exception as diag:
        logging.error(diag.__class__.__name__,':','executeBash',':',diag)
        return False

    for line in bashFilePtr.readlines():



"""
  MAIN
  V0 : monosession
"""

# Parameters
socks5 = '129.39.133.102'
serverName = '15.1.92.247'
oracleServer = 'vmlpdtbora010'
customer = 'korian'
sudoUser = 'oracle'

# Other variables
sessionBName = customer + '_ssh'
sessionName = ''

# search for an existing
for line in os.popen('tmux ls','r').readlines():
    if line.find(sessionBName) != -1:
        print('Do you want to reuse session: ' + line.split(':')[0] + '? [y/n] ', end="")
        if input() == 'y':
            sessionName = line.split(':')[0]
            break

# if no session has been found request creation of a new one
if sessionName == '':
    sessionName = sessionBName + 'S' + '_' + dateTime()
    windowsName = sessionBName + 'W' + '_' + dateTime()
    print ('please open a terminal window and launch "' + 'tmux new -s ' + sessionName + ' -n ' + windowsName + '"')
    print ('press y then return when you are ready: ', end="" )
    reply = input()
    if reply != 'y':
        logging.info('exiting, have a nice day')

logging.info('checking if tmux session exists ...')
if os.popen('tmux ls','r').read().find(sessionName) == -1:
    logging.error('main: tmux session not found')
    exit(-1)

tUserPass = readPwd(customer,'ssh',serverName)
connectSsh(sessionName,serverName,tUserPass[0],tUserPass[1],socks5)

wUserPass = readPwd(customer,'wallix',oracleServer)
if not wallixSelection(sessionName,oracleServer,wUserPass[0],wUserPass[1]):
    logging.error('wallixSelection: Unable to select a server')

if not sudo(sessionName,sudoUser):
    logging.error('sudo : Unable to sudo as ' + sudoUser)
