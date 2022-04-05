#!/usr/bin/python3
import tmux4sql
import os
from datetime import datetime # for session names individualisation
import time
import logging
import libtmux  # xserssion managemenr
import sys
import getopt








"""
 MAIN
"""

customer = ''
sshServer = ''
socks5=''
wallixAddr=''
destServer=''

try:
  opts, args = getopt.getopt(sys.argv[1:],"c:s:k:d:",["customer=","sshServer=","socks5=","destServer="])
  print (sys.argv[1:])
except getopt.GetoptError:
 print ('sshLogin.py -c <customer> -s <ssh servername> -k <socksServer> [-d <destination>]')
 sys.exit(2)

for opt, arg in opts:
    print(opt)
    if opt == '-h':
        print ('sshLogin.py -c <customer> -s <ssh servername> -k <sockServer> [-d <destination>]')
        sys.exit(2)
    elif opt in ("-c", "--customer"):
        customer = arg
    elif opt in ("-s", "--sshServer"):
        sshServer = arg
    elif opt in ("-k", "--socks5"):
        socks5=arg
    elif opt in ("-d", "--destServer"):
        destServer=arg

tUserPass = tmux4sql.readPwd(customer,'ssh',sshServer)

if customer == '' or sshServer == '':
    print ('sshLogin.py -c <customer> -s <ssh servername> -k <sockServer> [-d <destination>]')
    sys.exit(2)

print(destServer)
if destServer != '':
    sessionName =  customer + '_' + destServer
else:
    sessionName =  customer + '_' + sshServer

if tmux4sql.getXterm(sessionName) == False:
    print('unable to launch xterm')
    exit(1)

tUserPass = tmux4sql.readPwd(customer,'ssh',sshServer)
if not tUserPass:
    exit(2)

time.sleep(4)
tmux4sql.connectSsh(sessionName,sshServer,tUserPass[0],tUserPass[1],socks5)

if wallixAddr == '':
    time.sleep(4)
    wUserPass = tmux4sql.readPwd(customer,'wallix',destServer)
    if not tmux4sql.wallixSelection(sessionName,destServer,wUserPass[0],wUserPass[1]) == False:
        logging.error('wallixSelection: Unable to select a server')
