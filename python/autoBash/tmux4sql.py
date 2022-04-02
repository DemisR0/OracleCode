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
        logging.error('readPwdFile',':',diag)
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

def getTmuxSession(baseName = ''):
    """
    get a Tmux session Name. check if a session can be reused
    take a base for the session name
    """
    for line in os.popen('tmux ls','r').readlines():
        if line.find(baseName) != -1:
            print('Do you want to reuse session: ' + line.split(':')[0] + '? [y/n] ', end="")
            if input() == 'y':
                sessionName = line.split(':')[0]
                return sessionName
# if no session has been found request creation of a new one
    sessionName = baseName + 'S' + '_' + dateTime()
    windowsName = baseName + 'W' + '_' + dateTime()
    print ('please open a terminal window and launch "' + 'tmux new -s ' + sessionName + ' -n ' + windowsName + '"')
    print ('press y then return when you are ready: ', end="" )
    reply = input()
    if reply != 'y':
        logging.info('exiting, have a nice day')
    logging.info('checking if tmux session exists ...')
    if os.popen('tmux ls','r').read().find(sessionName) == -1:
        logging.error('main: tmux session not found')
        exit(-1)
    return sessionName
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
    for line in lines:
        if line.find(srvName) !=-1 :
            srvNum=line.split(" | ")[0].lstrip("|").lstrip(" ")
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
    for i in range(0,3):
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
    time.sleep(2)
    if os.popen('tmux capture-pane -pS -5 -t ' + sName ).read().find('\n' + userName) >= 0:
        return True
    return False
##-----------------------

def executeBashNoData(sName,bashFile):
    """
    exec a loop to launch a sql over all started DB
    """
    try:
        bashFilePtr = open(bashFile,'r')
    except Exception as diag:
        logging.error('executeBash',':',diag)
        return False
    tmuxClear(sName)
    for line in bashFilePtr.read().splitlines():
        os.system('tmux send-key -t ' + sName + ' \'' + line.rstrip() + '\' Enter')
    # check if oracle raised any error
    outPut = os.popen('tmux capture-pane -pS -100 -t ' + sName ).read()
    if outPut.find('ORA-') != -1:
        logging.error('executeBash',': oracle error occured')
        logging.error(' '.join(line.split()))
        return False
    return True
##-----------------------

def getMultiOraData(sName,bashFile,outFileName = ''):
    """
    exec a loop to launch a sql over all started DB
    params: tmux session, file to execute, filename for the data ouput
    """
    if outFileName == '':
        outFileName = sName
    try:
        bashFilePtr = open(bashFile,'r')
    except Exception as diag:
        logging.error('executeBash',':',diag)
        return False
    # prepare sql script
    tmuxClear(sName)
    print('tmux send-key -t ' + sName + ' "cat /dev/null > /tmp/script.sql" Enter')
    for line in bashFilePtr.read().splitlines():
        if line.find("'") > -1:
            print('tmux send-key -t ' + sName + ' " echo \" ' + line + '\" >> /tmp/script.sql" Enter')
            os.system('tmux send-key -t ' + sName + ' " echo \\" ' + line + '\\" >> /tmp/script.sql" Enter')
        else:
            print('tmux send-key -t ' + sName + ' " echo \''  + line + '\' >> /tmp/script.sql" Enter')
            os.system('tmux send-key -t ' + sName + ' " echo \''  + line + '\' >> /tmp/script.sql" Enter')
    bashFilePtr.close()
    bashHeader="""
ORAENV_ASK=NO
for i in `ps -ef | grep smon_ | cut -f3 -d _ | grep -v ASM | grep -v ^$ | sort | xargs`
do
ORACLE_SID=${i}; export ORACLE_SID
. oraenv
echo \$ORACLE_SID
sqlplus "/ as sysdba" @/tmp/script.sql
done
#rm /tmp/script.sql
"""
    os.system('tmux send-key -t ' + sName + ' \''  + bashHeader + '\' Enter')
    # sleep to wait the end of the remote execute
    time.sleep(20)
    os.system('tmux capture-pane -pS -100000 -t ' + sName + '> ' + outFileName)
    return True
## ----------------------

def parseOutput(sourceFile,destFile = 'output.csv',lineFilter = ''):
    """
    read de file create a new file with line containing the line filter, removing the line Filter in the process
    """
    try:
        open(destFile,'w').writelines(line.replace(lineFilter,'') for line in open(sourceFile,'r') if lineFilter in line)
    except Exception as diag:
        logging.error('tmux4sql.parseOutput',':',diag)
        return False
    return True
