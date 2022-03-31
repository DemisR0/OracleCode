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
        return None

    try:
        pwdFilePtr = open(filePath,'r')
    except Exception as diag:
        logging.error(diag.__class__.__name__,':','readPwdFile',':',diag)
        return None

    for line in pwdFilePtr:
        if line.find(entry) == 0:
            pwdFilePtr.close()
            return (line.split('\n')[0].split(entry)[1].split(':'))
    return None
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
        os.system('tmux send-key -t ' + sName + '\'' + sshCommand + '\' Enter' )
        print(os.popen('tmux capture-pane -pS -3 -t ' + sName ).read())
        #os.system('tmux capture-pane -pS -100 -t ' + sName )
    time.sleep(5)
    return None

def wallixSelection(sName,srvName,userName,password):
    """
    select server in wallix menu
    """
    lines = os.popen('tmux capture-pane -pS -100 -t ' + sName ).readlines()
    print(srvName+" "+userName+ " "+password)
    for line in lines:
        if line.find(srvName) !=-1 :
            srvNum=line.split(" | ")[0].lstrip("| ")
            print('"'+srvNum+'"')
            os.system('tmux send-key -t ' + sName + ' ' + srvNum + ' Enter')
            time.sleep(5)
            os.system('tmux send-key -t ' + sName + ' \'' + password + '\' Enter')
            break
            """
            panePtr.send_keys('ls', enter=True)
            """
            return srvNum
    return None

"""
  MAIN
  V0 : monosession
"""

# Parameters
socks5 = '129.39.133.102'
customer = 'korian'
sessionBName = customer + '_ssh'
domain = 'ssh'
serverName = '15.1.92.247'
oracleServer = 'vmlpdtbora010'

sessionName = sessionBName + 'S' + '_' + dateTime()
windowsName = sessionBName + 'W' + '_' + dateTime()

print ('please open a terminal window and launch "' + 'tmux new -s ' + sessionName + ' -n ' + windowsName + '"')
print ('press y then return when you are ready: ', end="" )
reply = input()
if reply != 'y':
    logging.info('exiting, have a nice day')

logging.info('checking if tmux session exists ...')
if os.popen('tmux ls','r').read().find(sessionName) == -1:
    logging.error('tmux session not found')
    exit(-1)

tUserPass = readPwd(customer,domain,serverName)
connectSsh(sessionName,serverName,tUserPass[0],tUserPass[1],socks5)
