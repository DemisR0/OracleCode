import os
import libtmux  # xserssion managemenr
from datetime import datetime # for session names individualisation
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
def connectSsh (panePtr,srvName,userName,password,socksServer = '',socksSrvPort = '1080'):
    """
    create an ssh session throught the windows pane provided
    """
    sshCommand='sshpass -p \''+password+' ssh "'+userName+'@'+srvName
    if sockServer != '':
        sshCommand = sshCommand+' -o "ProxyCommand=nc -X 5 -x '+socksServer+':'+socksSrvPort+'%h %p"'
    panePtr.send_keys(ssCommand, enter=True)
    print('\n'.join(panePtr.cmd('capture-pane', '-p').stdout))
    return None
"""
  MAIN
"""



sName = sessionName+'_'+dateTime()

try:
    #stream = os.system('tmux new-session -n ' + sName + ' -s ' + sName)
    #session = server.find_where({ "session_name": sName })
    #window = session.select_window("0")
    #tmuxPane = window.select_pane("%0")
    server = libtmux.Server()
    session =  server.new_session(sName)
    win1 = session.new_window(attach=True, window_name=sName)
    myPane = win1.list_panes()[0]
except Exception as diag:
    print(diag.__class__.__name__,':','createTermSession',':',diag)
    return None
