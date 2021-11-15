#!/usr/bin/perl

#==================================================================================================
# Description             : RMAN backup on SBT_TAPE (TSM), For UNIX, LINUX and WINDOWS
# Oracle Version          : ORACLE Version 9.2.0 & +
#--------------------------------------------------------------------------------------------------
# Created on              : April 2012 - IBM La Gaude - Yves Meyran - SMI
# Version Number          : V1.18 - 14 January 2014
#--------------------------------------------------------------------------------------------------
# Usage                   : Starting using UNIX Session (nohup) / crontab or TSM Scheduler
# Script Parameters       : $1 == Backup type (see below)
#                         : $2 == Oracle Instance Name (TNS_NAME)
#                         : $3 == TAG : method for multi retention : DLY for DAILY | WLY for Weekly | MLY for Monthly backups | EXC for special backups
#                         : $4 == days/versions of retention (for delete_obsolete) || % of filesystem usage (for backup_archivelog_emergency)
#                         : $4 or $5 == USECATALOG if you want to use a Catalog
#--------------------------------------------------------------------------------------------------
# Special Return Codes    :  24 = script already running
#                         :  25 = configuration error
#                         :  26 = lost objects in TSM to delete manually
#                         :  27 = more than one API:ORACLE filespace
#                         :  28 = // no more used //
#                         :  29 = expired objects to delete manually
#                         : 100 = RMAN Command Error
#==================================================================================================

%config=();                             # TSM Configuration Parameters.
%configparam=();                        # Extra Configuration Parameters.

# - Constants -
# -------------
# Here are the possible "Backup Type" / RMAN Functions :

$backuptype[1]="connexioninfos";
$backuptype[2]="check_undeleted_backups";
$backuptype[3]="delete_obsolete_tag";
$backuptype[4]="delete_obsolete_days";
$backuptype[5]="delete_obsolete_versions";
$backuptype[6]="backup_archivelog";
$backuptype[7]="backup_archivelog_emergency";
$backuptype[8]="backup_controlfile";
$backuptype[9]="backup_spfile";
$backuptype[10]="backup_db_inc0_mount";     # IMPORTANT : This is an OFFLINE Backup.
$backuptype[11]="backup_db_inc1_mount";     # IMPORTANT : This is an OFFLINE Backup.
$backuptype[12]="backup_db_inc0_open";
$backuptype[13]="backup_db_inc1_open";
$backuptype[14]="backup_db_full_mount";
$backuptype[15]="backup_db_full_open";
$backuptype[16]="check_database_corruption";

$nbbt=16;                               # Number of Backup Types.

# Catalog configuration (used if you use USECATALOG as a parameter)
$CATALOG="REPPRD04";
$USERRMAN="RMAN";
$PSSWRMAN="RMAN";

# Offline Backups, Monitoring Stop / Start
$MONITORING_STOP="MONITORING_STOP not_used";
$MONITORING_START="MONITORING_START not_used";

# Check for filespaces (yes|no)
$CHECK_FILESPACES="yes";

$sep="===================================================================================";

# - OS Type -
# -----------
$OS=uc($^O);                            # OS Name : AIX, LINUX, MSWIN32.

if ($OS eq "MSWIN32")
    {
    $verwin="";                         # Windows 32 Bits by default.
    $direc="C:\\Windows\\SysWOW64";
    if (-d $direc) {$verwin="64";}      # Windows 64 bits.
    }

# - Checking User -
# -----------------
if ($OS eq "AIX" || $OS eq "LINUX")
    {
    $line=`id`;
    @tmp=split(" ",$line);
    $v1=$tmp[0];
    if ($v1 !~ "root")
        {
        print "Only root can run this script !\n";
        print "Finish.\n\n";
        exit(1);
        }
    }

# - Profile File -
# ----------------
if ($OS eq "AIX")   {$profile=". .profile";}
if ($OS eq "LINUX") {$profile=". .bash_profile";}

# - Checking Parameters -
# -----------------------
$nb=scalar(@ARGV);

if ($nb < 3)
    {
    print "\n";
    print "There is no argument to process.\n";
    print "You MUST specify the Backup Type, the Instance Name to backup and the Tag Type.\n";
    print "Exiting with Return Code 255 ...\n";
    print "Finish.\n\n";
    exit(255);
    }

$p1=$ARGV[0];
$ok=0;
for $i (1..$nbbt)
    {
    if ($p1 eq $backuptype[$i]) {$ok=1;}
    }

if ($ok == 0)
    {
    print "\n";
    print "Bad Backup Type. Please select one of the following Backup Types :\n";
    for $i (1..$nbbt)
        {
        print "  $backuptype[$i]\n";
        }
    print "Finish.\n\n";
    exit(255);
    }

$p3=$ARGV[2];
$ok=0;
if ($p3 eq "DLY") {$ok=1;}
if ($p3 eq "WLY") {$ok=1;}
if ($p3 eq "MLY") {$ok=1;}
if ($p3 eq "YLY") {$ok=1;}
if ($p3 eq "EXC") {$ok=1;}
if ($ok == 0)
    {
    print "\n";
    print "Bad TAG Type. Please select one of the following values :\n";
    print "DLY, WLY, MLY, YLY or EXC\n";
    print "Finish.\n\n";
    exit(255);
    }

$p4=$ARGV[3];
$test=0;
if ($p1 eq "delete_obsolete_tag")         {$test=1;}
if ($p1 eq "delete_obsolete_days")        {$test=1;}
if ($p1 eq "delete_obsolete_versions")    {$test=1;}
if ($p1 eq "backup_archivelog_emergency") {$test=1;}

if ($test == 1)
    {
    if ($p4 eq "")
        {
        print "You MUST specify days or versions of retention for delete_obsolete\n";
        print "OR percentage of FS usage for backup_archivelog_emergency\n";
        print "Finish.\n\n";
        exit(255);
        }

    if ($p4 == 0)
        {
        print "Invalid number of Retention Days. Value must be > 0 ...\n";
        print "Finish.\n\n";
        exit(255);
        }
    }

# - Backup Parameters -
# ---------------------
$BACKUP_TYPE=$ARGV[0];
$ORACLE_SID=$ARGV[1];
$TAG=$ARGV[2];
$RETENTION_OR_FSUSAGE=$ARGV[3];
$USECATALOG=$ARGV[4];

if ($TAG ne "DLY")
    {
    $test=0;
    if ($BACKUP_TYPE eq "backup_db_inc1_open")  {$test=1;}
    if ($BACKUP_TYPE eq "backup_db_inc1_mount") {$test=1;}
    if ($test == 1)
        {
        print "When the backup TAG is not DLY, you must run a LEVEL 0 backup.\n";
        exit(1);
        }
    }

# - Tags -
# --------
$TAG_FULL_MOUNT=$TAG."_BDB_F_M";
$TAG_FULL_OPEN=$TAG."_BDB_F_O";
$TAG_INC_0_MOUNT=$TAG."_BDB_IL0_M";
$TAG_INC_1_MOUNT=$TAG."_BDB_IL1_M";
$TAG_INC_2_MOUNT=$TAG."_BDB_IL2_M";
$TAG_INC_0_OPEN=$TAG."_BDB_IL0_O";
$TAG_INC_1_OPEN=$TAG."_BDB_IL1_O";
$TAG_INC_2_OPEN=$TAG."_BDB_IL2_O";
$TAG_CTL=$TAG."_BCF";
$TAG_SPF=$TAG."_BSP";
$TAG_ARCH=$TAG."_BAR";

$FORMAT_FULL_MOUNT=$TAG_FULL_MOUNT;
$FORMAT_FULL_OPEN=$TAG_FULL_OPEN;
$FORMAT_INC_0_MOUNT=$TAG_INC_0_MOUNT;
$FORMAT_INC_1_MOUNT=$TAG_INC_1_MOUNT;
$FORMAT_INC_2_MOUNT=$TAG_INC_2_MOUNT;
$FORMAT_INC_0_OPEN=$TAG_INC_0_OPEN;
$FORMAT_INC_1_OPEN=$TAG_INC_1_OPEN;
$FORMAT_INC_2_OPEN=$TAG_INC_2_OPEN;
$FORMAT_CTL=$TAG_CTL;
$FORMAT_SPF=$TAG_SPF;
$FORMAT_ARCH=$TAG_ARCH;

# - Unique Instance ID -
# ----------------------
@today=localtime(time);
$today[4]=$today[4]+1;                  # Month (1 to 12).
$today[5]=$today[5]+1900;
$tday=sprintf("%02d",$today[3]);
$tmon=sprintf("%02d",$today[4]);
$tyea=$today[5];
$tsec=sprintf("%02d",$today[0]);
$tmin=sprintf("%02d",$today[1]);
$theu=sprintf("%02d",$today[2]);
$instanceid=$theu.$tmin.$tsec;          # Unique Instance ID.

# - Oracle User and Local Path -
# ------------------------------
if ($OS eq "AIX" || $OS eq "LINUX")
    {
    $cmd="ps -ef | grep -w \"ora_pmon_$ORACLE_SID\" | grep -vw grep";
    $line=`$cmd`;
    @tmp=split(" ",$line);
    $ORA_USER=$tmp[0];

    $localpath=`pwd`;
    chop($localpath);
    }

if ($OS eq "MSWIN32")
    {
    $ORA_USER=$ENV{'USERNAME'};         # Windows User Name.
    $localpath="C:\\exploit";
    $cmd="mkdir $localpath";
    system ($cmd);
    }

# - Extra Configuration Parameters -
# ----------------------------------
# Naming Convention of the Extra Parameters File :
# param_"OracleInstanceName".cfg
# Exemple : param_ORA21.cfg
#
# This Configuration File is located on the "localpath" Directory as follow :
# - AIX and LINUX ... : The same Directory than the Perl Script
# - Windows ......... : C:\exploit
#
# This file contains 2 extra Parameters :
# 1 : log_retention ... : Number of days of Archive logs Retention (in days)
# 2 : ora_home ........ : Oracle Home Directory (for Windows only)
#
# Exemple for Windows :
# log_retention=4
# ora_home=D:\\app\\oracle\\product\\11.2

$LOG_RETENTION="";                      # Init of The Retention Parameter.
$filename="param_".$ORACLE_SID.".cfg";

if ($OS eq "AIX" || $OS eq "LINUX")
    {
    $filecfg=$localpath."/".$filename;
    }

if ($OS eq "MSWIN32")
    {
    $filecfg=$localpath."\\".$filename;
    }

if (-f $filecfg)                        # File Exists.
    {
    open (CONF,"<$filecfg");
    while ($line=<CONF>)
        {
        $line=~s/\n$//;                 # On supprime le \n � la fin.
        $line=~s/ +$//;                 # On supprime les Espaces de la fin.
        if ($line=~/^#/) {next;}        # Ligne de Commentaires.
        if ($line=~/^\'/) {next;}       # Ligne de Commentaires.
        if ($line=~/^$/) {next;}        # Ligne Vide.
        if ($line=~/=/)
            {
            ($param,$tmp1)=split(/=/,$line);
            ($value,$tmp2)=split("#",$tmp1);
            $value=&trim($value);
            $param=uc($param);
            $configparam{$param} = $value;
            }
        }

    $LOG_RETENTION=$configparam{"LOG_RETENTION"};
    close CONF;
    }

# - LOG File -
# ------------
$logname="";
$logname=$logname . "rman_backup_tag." . $ORACLE_SID . ".";
$logname=$logname . $BACKUP_TYPE . "." . $TAG . ".";
$logname=$logname . $tyea . "-" . $tmon . "-" . $tday . "-".$instanceid . ".log";

if ($OS eq "AIX" || $OS eq "LINUX")
    {
    $LOG_DIR="/exploit/logs/tsm";
    $cmd="mkdir -p $LOG_DIR";
    system ($cmd);
    $LOGFILE=$LOG_DIR."/".$logname;
    }

if ($OS eq "MSWIN32")
    {
    $LOG_DIR=$localpath."\\logs\\tsm";
    $LOGFILE=$LOG_DIR."\\".$logname;
    $cmd="mkdir $LOG_DIR";
    system ($cmd);
    }

# - OPT And ORATAB Configuration Files -
# --------------------------------------
$TDPO_OPTFILE="";                       # Init.

if ($OS eq "AIX" || $OS eq "LINUX")
    {
    $name="tdpo_$ORACLE_SID.opt";       # OPT Configuration File Name.

    $paths[1]="/usr/tivoli/tsm/client/oracle/bin";
    $paths[2]="/usr/tivoli/tsm/client/oracle/bin64";
    $paths[3]="/opt/tivoli/tsm/client/oracle/bin";
    $paths[4]="/opt/tivoli/tsm/client/oracle/bin64";

    for $i (1..4)                       # Test 4 Directories.
        {
        $file=$paths[$i] . "/" . $name;
        if (-f $file)                   # File Exists.
            {
            $TDPO_OPTFILE=$file;
            last;
            }
        }

    $oratabfile="/etc/oratab";
    if (!-f $oratabfile)
        {
        $msg="";
        $msg=$msg."The File $oratabfile is not present.\n";
        $msg=$msg."Cannot load the Oracle Environement.\n";
        &Trace($msg);
        exit(1);
        }
    }

if ($OS eq "MSWIN32")                   # Windows.
    {
    $name="tdpo_$ORACLE_SID.opt";       # OPT Configuration File Name.

    $paths[1]="C:\\Progra~1\\Tivoli\\TSM\\AgentOBA";
    $paths[2]="C:\\Progra~2\\Tivoli\\TSM\\AgentOBA";

    if ($verwin eq "64")                # Windows 64 bits.
        {
        $paths[1]="C:\\Progra~1\\Tivoli\\TSM\\AgentOBA64";
        $paths[2]="C:\\Progra~2\\Tivoli\\TSM\\AgentOBA64";
        }

    for $i (1..2)                       # Test 2 Directories.
        {
        $file=$paths[$i] . "\\" . $name;
        if (-f $file)                   # File Exists.
            {
            $TDPO_OPTFILE=$file;
            last;
            }
        }
    }

# - Oracle Home Directory -
# -------------------------
$ORACLE_HOME="";                        # Init.
$SID_BASE=$ORACLE_SID;
chop($SID_BASE);                        # Suppress the Last Caracter.

if ($OS eq "AIX" || $OS eq "LINUX")
    {
    open (ORA,"<$oratabfile");
    while ($line=<ORA>)
        {
        $line=~s/\n$//;                 # On supprime le \n � la fin.
        $line=~s/ +$//;                 # On supprime les Espaces de la fin.
        if ($line=~/^#/) {next;}        # Ligne de Commentaires.
        if ($line=~/^\*/) {next;}       # Ligne de Commentaires.
        if ($line=~/^\'/) {next;}       # Ligne de Commentaires.
        if ($line=~/^$/) {next;}        # Ligne Vide.
        @tmp=split(":",$line);
        $v1=$tmp[0];

        if ($v1 eq $ORACLE_SID)
            {
            $ORACLE_HOME=$tmp[1];
            last;
            }

        if ($v1 eq $SID_BASE)           # RAC Database.
            {
            $ORACLE_HOME=$tmp[1];
            last;
            }
         }

    close ORA;

    if ($ORACLE_HOME eq "")
        {
        $msg="";
        $msg=$msg."The ORACLE_HOME is not found.\n";
        $msg=$msg."Cannot load the Oracle Environement.\n";
        &Trace($msg);
        exit(1);
        }
    }

if ($OS eq "MSWIN32")                   # Windows.
    {
    $par=$configparam{"ORA_HOME"};      # ORA_HOME Extra Parameter.
    if ($par ne "")
        {
        $ENV{'ORACLE_HOME'}=$par;
        $ORACLE_HOME=$par;
        }
    }

# - RMAN Connection -
# -------------------
$RMAN_CONNECTION="rman target / nocatalog";     # RMAN connection by Default.

if (uc($RETENTION_OR_FSUSAGE) eq "USECATALOG" || uc($USECATALOG) eq "USECATALOG")
    {
    $RMAN_CONNECTION="rman target / rcvcat=$USERRMAN/$PSSWRMAN\@$CATALOG";
    }

# - Display Parameters -
# ----------------------
&CreateTimestamp;
$msg="";
$msg=$msg."\n";
$msg=$msg."$sep\n";
$msg=$msg."[$BACKUP_TYPE] Starting for Instance $ORACLE_SID : $timestamp\n";
$msg=$msg."$sep\n";
$msg=$msg."\n";
$msg=$msg."Parameters :\n";
$msg=$msg."------------\n";
$msg=$msg."OS Name ........... : $OS $verwin\n";
$msg=$msg."Backup Type ....... : $BACKUP_TYPE\n";
$msg=$msg."Oracle Instance ... : $ORACLE_SID\n";
$msg=$msg."TAG ............... : $TAG\n";
$msg=$msg."Oracle User ....... : $ORA_USER\n";
$msg=$msg."Instance ID ....... : $instanceid\n";
$msg=$msg."Local Path ........ : $localpath\n";
$msg=$msg."TDPO_OPTFILE ...... : $TDPO_OPTFILE\n";
$msg=$msg."Oracle Home ....... : $ORACLE_HOME\n";
$msg=$msg."RMAN Connection ... : $RMAN_CONNECTION\n";

if ($LOG_RETENTION ne "")
    {
    $msg=$msg."LOG RETENTION ..... : $LOG_RETENTION\n";
    }

&Trace($msg);

print "Log File .......... : $LOGFILE\n";

# - Test OPT Configuration File -
# -------------------------------
if ($TDPO_OPTFILE eq "")
    {
    $RC=24;
    $msg="";
    $msg=$msg."\n";
    $msg=$msg."TSM OPT Configuration File not found ...\n";
    $msg=$msg."Finish (Return Code=$RC).\n\n";
    &Trace($msg);
    exit($RC);
    }

# - Is Script Running ? -
# -----------------------
$filename="Running-" . $ORACLE_SID . ".pid";

if ($OS eq "AIX" || $OS eq "LINUX")
    {
    $filerun=$localpath."/".$filename;
    }

if ($OS eq "MSWIN32")
    {
    $filerun=$localpath."\\".$filename;
    }

if (-f $filerun)
    {
    $RC=24;
    $msg="";
    $msg=$msg."\n";
    $msg=$msg."Script is running for $ORACLE_SID ...\n";
    $msg=$msg."Finish (Return Code=$RC).\n\n";
    &Trace($msg);
    exit($RC);
    }

open(TXT,">$filerun");
print TXT "Running\n";
close TXT;

# - OPT Configuration File Parameters -
# -------------------------------------
open (CONF,"<$TDPO_OPTFILE");
while ($line=<CONF>)
    {
    $line=~s/\n$//;                     # On supprime le \n � la fin.
    $line=~s/ +$//;                     # On supprime les Espaces de la fin.
    if ($line=~/^#/) {next;}            # Ligne de Commentaires.
    if ($line=~/^\*/) {next;}           # Ligne de Commentaires.
    if ($line=~/^\'/) {next;}           # Ligne de Commentaires.
    if ($line=~/^$/) {next;}            # Ligne Vide.
    ($param,$value)=split(" ",$line);
    $value=&trim($value);
    $config{$param} = $value;
    }
close CONF;

# - Rotating Logfiles -
# ---------------------
$older=30;                              # Age of Files to be Deleted.
print "\n";
print "Cleaning [$ORACLE_SID] old log files ($older days older) ...\n";

$mask=".*\.log";                        # List of Files with ".log" extension.
opendir DIR, $LOG_DIR;
@files=grep {/$mask/} readdir(DIR);
closedir DIR;
$nbfich=scalar(@files);                 # Number of Files.

if ($nbfich > 0)
    {
    for $fi (0..$nbfich-1)              # Processing Files.
        {
        $file=$files[$fi];

        if ($file =~ $ORACLE_SID)
            {
            if ($OS eq "AIX" || $OS eq "LINUX")
                {
                $lgfi=$LOG_DIR."/$file";    # Complete Name.
                }

            if ($OS eq "MSWIN32")
                {
                $lgfi=$LOG_DIR."\\$file";   # Complete Name.
                }

            $age= -M $lgfi;                 # File Age.
            $age=int($age);
            if ($age > $older)
                {
                unlink $lgfi;
                }
            }
        }
    }

# =========
# - START -
# =========

$tempo=0;
if ($BACKUP_TYPE eq "backup_db_inc0_mount") {$tempo=1;}
if ($BACKUP_TYPE eq "backup_db_inc1_mount") {$tempo=1;}
if ($BACKUP_TYPE eq "backup_db_inc2_mount") {$tempo=1;}
if ($BACKUP_TYPE eq "backup_db_full_mount") {$tempo=1;}

if ($tempo == 1)
    {
    foreach $count (5,4,3,2,1)
        {
        print "An Offline Backup for $ORACLE_SID will start in $count minutes.\n";
        sleep(60);
        }
    }

# - Working Files -
# -----------------
if ($OS eq "AIX" || $OS eq "LINUX")
    {
    $TMPFILE="/tmp/$ORACLE_SID-$instanceid.tmp";            # Temporary File.
    $cmdfile="/tmp/$ORACLE_SID-$instanceid-1.cmd";          # Temporary RMAN Command File N�1.
    $sqlfile="/tmp/SQL-$instanceid.sql";                    # Temporary SQL Command File.
    }

if ($OS eq "MSWIN32")
    {
    $TMPDIR=$localpath."\\Tmp";
    $cmd="mkdir $TMPDIR";
    system ($cmd);
    $TMPFILE="$TMPDIR\\$ORACLE_SID-$instanceid.tmp";        # Temporary File.
    $cmdfile="$TMPDIR\\$ORACLE_SID-$instanceid-1.cmd";      # Temporary RMAN Command File N�1.
    $sqlfile="$TMPDIR\\SQL-$instanceid.sql";                # Temporary SQL Command File.

    $ENV{'ORACLE_SID'}=$ORACLE_SID;
    }

# - SPFILE -
# ----------
$msg="";
$msg=$msg."\n";
$msg=$msg."$sep\n\n";
$msg=$msg."Usage of SPFILE :\n";
$msg=$msg."-----------------\n";
&Trace($msg);

$SPFILE=0;                          # Init Flag SPFILE.
open(CMD,">$sqlfile");
print CMD "show parameter spfile;\n";
print CMD "exit\n";
close CMD;
&SQLPLUS_Command;

if (-f $TMPFILE)
    {
    open (TMP,"<$TMPFILE");
    while ($line=<TMP>)
        {
        $line=~s/\n$//;             # On supprime le \n � la fin.
        $ch=substr($line,0,6);
        if (uc($ch) eq "SPFILE")
            {
            @tmp=split(" ",$line);
            $sp=$tmp[2];            # SPFILE Name.
            $sp=&trim($sp);
            if (length($sp) > 0 )
                {
                $SPFILE=1;
                }
            }
        }
    close TMP;
    }

$msg="\n";
if ($SPFILE == 0) {$msg=$msg."SPFILE Usage=NO\n";}
if ($SPFILE == 1) {$msg=$msg."SPFILE Usage=YES\n";}
$msg=$msg."$sep\n\n";
&Trace($msg);

# - Launch Command -
# ------------------
$msg="";
$msg=$msg."\n";
$msg=$msg."Launch Command :\n";
$msg=$msg."----------------\n";
&Trace($msg);

$RC=0;                                  # Init of the Return Code.

if ($BACKUP_TYPE eq $backuptype[1])  {&connexioninfos;}
if ($BACKUP_TYPE eq $backuptype[2])  {&check_undeleted_backups};
if ($BACKUP_TYPE eq $backuptype[3])  {&delete_obsolete_tag};
if ($BACKUP_TYPE eq $backuptype[4])  {&delete_obsolete_days};
if ($BACKUP_TYPE eq $backuptype[5])  {&delete_obsolete_versions};
if ($BACKUP_TYPE eq $backuptype[6])  {&backup_archivelog};
if ($BACKUP_TYPE eq $backuptype[7])  {&backup_archivelog_emergency};
if ($BACKUP_TYPE eq $backuptype[8])  {&backup_controlfile};
if ($BACKUP_TYPE eq $backuptype[9])  {&backup_spfile};
if ($BACKUP_TYPE eq $backuptype[10]) {&backup_db_inc0_mount};
if ($BACKUP_TYPE eq $backuptype[11]) {&backup_db_inc1_mount};
if ($BACKUP_TYPE eq $backuptype[12]) {&backup_db_inc0_open};
if ($BACKUP_TYPE eq $backuptype[13]) {&backup_db_inc1_open};
if ($BACKUP_TYPE eq $backuptype[14]) {&backup_db_full_mount};
if ($BACKUP_TYPE eq $backuptype[15]) {&backup_db_full_open};
if ($BACKUP_TYPE eq $backuptype[16]) {&check_database_corruption};

if ($RC eq "") {$RC=1;}

if ($RC != 100)                         # Return Code 100 : RMAN Error.
    {
    if ($RC != 255)                     # Return Code 255 : Something Failed.
        {
        if ($RC != 26)                  # "check_undeleted_backups" Code.
            {
            if ($BACKUP_TYPE eq "delete_obsolete_tag" || $BACKUP_TYPE eq "delete_obsolete_days")
                {
                $BACKUP_TYPE="check_undeleted_backups";
                &check_undeleted_backups;
                }
            }
        }
    }

# - End -
# -------
if (-f $filerun) {unlink $filerun;}
if (-f $TMPFILE) {unlink $TMPFILE;}
if (-f $cmdfile) {unlink $cmdfile;}

&CreateTimestamp;
$msg="";
$msg=$msg."\n";
$msg=$msg."$sep\n";
$msg=$msg."[$BACKUP_TYPE] Finished for Instance $ORACLE_SID : $timestamp\n";
$msg=$msg."Return Code : $RC\n";
$msg=$msg."$sep\n";
$msg=$msg."\n";
&Trace($msg);

exit($RC);


# =============
# - FUNCTIONS -
# =============

# 1 - Displays connexion informations to RMAN and TSM -
# =====================================================
sub connexioninfos
    {
    $DSMI_ORC_CONFIG=$config{"DSMI_ORC_CONFIG"};
    $TDPO_NODE=$config{"TDPO_NODE"};

    if ($OS eq "AIX" || $OS eq "LINUX")
        {
        if ($DSMI_ORC_CONFIG ne "" )
            {
            $ENV{'DSM_CONFIG'}=$DSMI_ORC_CONFIG;
            }
        else
            {
            $dsmc_opt="-se=$TDPO_NODE";
            }
        }

    if ($OS eq "MSWIN32")
        {
        $dsmc_opt="-optfile=$TDPO_NODE";
        }

    if ($DSMI_ORC_CONFIG eq "" && $TDPO_NODE eq "")
        {
        $msg="";
        $msg=$msg."If you need to connect to TSM  : Cannot determine TSM configuration,\n";
        $msg=$msg."DSMI_ORC_CONFIG and/or TDPO_NODE not defined in $TDPO_OPTFILE\n";
        &Trace($msg);
        }
    else
        {
        $msg="";
        $msg=$msg."If you need to connect to TSM :\n";
        $msg=$msg."export DSM_CONFIG=$DSMI_ORC_CONFIG\n";
        $msg=$msg."dsmc $dsmc_opt\n";
        &Trace($msg);
        }

    $msg="";
    $msg=$msg."If you need to connect to RMAN :\n";
    $msg=$msg."su - $ORA_USER -c 'export ORACLE_SID=$ORACLE_SID ;\n";
    $msg=$msg."$ORACLE_USER_CMD$RMAN_CONNECTION'\n";
    $msg=$msg."Allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    &Trace($msg);
    }

# 2 - Function check_undeleted_backups -
# ======================================
sub check_undeleted_backups
    {
#   This function checks for backups which have to be deleted,
#   called after delete_obsolete_* functions (must be called by root).

    $DSMI_ORC_CONFIG=$config{"DSMI_ORC_CONFIG"};
    $TDPO_NODE=$config{"TDPO_NODE"};
    $TDPO_FS=$config{"TDPO_FS"};

    if ($DSMI_ORC_CONFIG eq "" && $TDPO_NODE eq "")
        {
        $msg="Cannot determine TSM configuration, DSMI_ORC_CONFIG and/or TDPO_NODE not defined in $TDPO_OPTFILE\n";
        &Trace($msg);
        $RC=25;
        return;
        }

    if ($TDPO_FS eq "")
        {
        $msg="Cannot determine TDPO_FS, TDPO_FS not defined in $TDPO_OPTFILE\n";
        &Trace($msg);
        $RC=25;
        return;
        }

    if ($OS eq "AIX" || $OS eq "LINUX")
        {
        if ($DSMI_ORC_CONFIG ne "")
            {
            $ENV{'DSM_CONFIG'}=$DSMI_ORC_CONFIG;
            }
        else
            {
            $dsmc_opt="-se=$TDPO_NODE";
            }
        }

    if ($OS eq "MSWIN32")
        {
        $dsmc_opt="-optfile=$TDPO_NODE";
        }

#   Get the date at format YYYY MM DD (tsm dateformat=5)
#   Determine the oldest entry we must have : localdate - ${RETENTION_OR_FSUSAGE}
#   TSM 6.2 switch file to inactive_version instead of suppress it - so add 1 day + to allow expir to delete the file

    $inc=-($RETENTION_OR_FSUSAGE+35);
    ($tday,$tmon,$tyea)=&incrementdate($inc);
    $maxdate=$tyea.".".$tmon.".".$tday;

   if ($OS eq "AIX" || $OS eq "LINUX")
        {
        $cmd="";
        $cmd=$cmd."dsmc q backup /$TDPO_FS//$TAG* -subdir=yes -DATEformat=5 ";
        $cmd=$cmd."-enablelanfree=no -todate=$maxdate $dsmc_opt >$TMPFILE 2>&1";
 $obsoleteDelCmd = "dsmc delete backup -noprompt /$TDPO_FS//$TAG* -subdir=yes -DATEformat=5 -enablelanfree=no -todate=$maxdate $dsmc_opt >$TMPFILE 2>&1";
}

    if ($OS eq "MSWIN32")
        {
        $cmd="";
        $cmd=$cmd."dsmc q backup /$TDPO_FS/$TAG* -subdir=yes -DATEformat=5 ";
        $cmd=$cmd."-enablelanfree=no -todate=$maxdate $dsmc_opt >$TMPFILE 2>&1";
        }

    $msg="";
    $msg=$msg."\n";
    $msg=$msg."Checking lost objects using TSM Repository :\n";
    $msg=$msg."  DSMI_ORC_CONFIG ... : $DSMI_ORC_CONFIG\n";
    $msg=$msg."  TDPO_NODE ......... : $TDPO_NODE\n";
    $msg=$msg."  TDPO_FS ........... : $TDPO_FS\n";
    $msg=$msg."  dsmc_opt .......... : $dsmc_opt\n";
    $msg=$msg."  Maxdate  .......... : $maxdate\n";
    $msg=$msg."TSM Command :\n";
    $msg=$msg.$cmd."\n\n";
    &Trace($msg);

    system ($cmd);
    $RC=$?;                             # Return Code.

    $msg="Return Code of dsmc command : $RC\n";
    &Trace($msg);

    if ($RC != 0)
        {
        $mg="";
        $RC=25;

        open (FILE,"<$TMPFILE");
        while ($line=<FILE>)
            {
            $line=~s/\n$//;             # On supprime le \n � la fin.
            $line=&trim($line);
            if ($line =~ "ANS1036S") {$mg="Invalid Parameters";}
            if ($line =~ "ANS1038S") {$mg="Invalid option specified";}
            if ($line =~ "ANS1353E") {$mg="Session rejected: Unknown or incorrect ID entered";}
            if ($line =~ "ANS1092W") {$mg="No files matching search criteria were found";$RC=0;}
            }
        close FILE;

        if ($mg ne "")
            {
            $msg="$mg\n";
            &Trace($msg);
            }
        else
            {
            $msg="Cannot get TSM objects list, here is the log :\n";

            open (FILE,"<$TMPFILE");
            while ($line=<FILE>)
                {
                $line=~s/\n$//;         # On supprime le \n � la fin.
                $msg=$msg."$line\n";
                }
            close FILE;
            &Trace($msg);
            }

        return;
        }

    $nbli=0;
    open (FILE,"<$TMPFILE");
    while ($line=<FILE>)
        {
        $line=~s/\n$//;                 # On supprime le \n � la fin.
        $line=&trim($line);
        if ($line ne "") {$nbli=$nbli+1;}
        }
    close FILE;

    if ($nbli > 0)
        {
  &Trace("\nLost objects will be deleted automatically by following command: ");
        &Trace($obsoleteDelCmd);
        &Trace("\n\n");
        system ($obsoleteDelCmd);
        $RC=$?;
        &Trace("Command finished with RC: $RC. Now going to recheck");
        &check_undeleted_backups;
        return;

}

    $msg="No lost objects, OK\n";
    &Trace($msg);

    if ($CHECK_FILESPACES eq "yes")
        {
        $cmd="dsmc q fi -enablelanfree=no $dsmc_opt >$TMPFILE 2>&1";

        $msg="";
        $msg=$msg."\n";
        $msg=$msg."Checking number of API:ORACLE Filespaces ...\n";
        $msg=$msg."TSM Command :\n";
        $msg=$msg.$cmd."\n\n";
        &Trace($msg);

        system ($cmd);
        $RC=$?;                         # Return Code.
        $number_of_filespaces=0;        # Init Number of FileSpaces.

        open (FILE,"<$TMPFILE");
        $msg="";
        while ($line=<FILE>)
            {
            $line=~s/\n$//;             # On supprime le \n � la fin.
            $line=~s/ +$//;             # On supprime les Espaces de la fin.
            if ($line =~ "API:ORACLE")
                {
                $line=&trim($line);
                $msg=$msg."$line\n";
                @tmp=split(" ",$line);
                $number_of_filespaces=$tmp[0];
                last;
                }
            }
        close FILE;
        &Trace($msg);

        if ($RC != 0 || $number_of_filespaces == 0)
            {
            $msg="Cannot determine number of API:ORACLE filespaces, here is the log :\n";
            open (FI,"<$TMPFILE");
            while ($line=<FI>)
                {
                $line=~s/\n$//;         # On supprime le \n � la fin.
                $msg=$msg."$line\n";
                }
            close FI;
            &Trace($msg);
            $RC=25;
            return;
            }

        if ($number_of_filespaces != 1)
            {
            $msg="";
            $msg=$msg."$number_of_filespaces API:ORACLE filespaces instead of 1, some should be deleted manually\n";
            $msg=$msg."API:ORACLE filespace used      : $TDPO_FS\n";
            $msg=$msg."TSM commands to use :\n";
            $msg=$msg."export DSM_CONFIG=$DSMI_ORC_CONFIG\n";
            $msg=$msg."dsmc $dsmc_opt\n";
            $msg=$msg."query filespace\n";
            $msg=$msg."delete filespace <other_filespaces>\n";
            $msg=$msg."If you need to connect to RMAN :\n";
            $msg=$msg."su - $ORA_USER -c 'export ORACLE_SID=$ORACLE_SID\n";
            $msg=$msg."$ORACLE_USER_CMD$RMAN_CONNECTION'\n";
            $msg=$msg."allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
            &Trace($msg);
            $RC=27;
            return;
            }

        $msg="1 API:ORACLE Filespace, OK\n";
        &Trace($msg);
        }

    $RC=0;
    }

# 3 - Function delete_obsolete_tag -
# ==================================
sub delete_obsolete_tag
    {
#   This function deletes obsolete backups. The retention is set by the third
#   and fourth argument specified when launching the script.

    &CreateTimestamp;
    $msg="";
    $msg=$msg."==> Beginning RMAN Delete Obsolete Backups in days retention with Tags : $timestamp\n";
    $msg=$msg."==> Number of days : $RETENTION_OR_FSUSAGE, Used Tag : $TAG\n";
    $msg=$msg."Reported object as TO BE DELETED :\n";
    $msg=$msg."\n";
    &Trace($msg);

    $RC=0;
    $RET=$RETENTION_OR_FSUSAGE+1;       # We Add One Day.

#   1 - Check object to be deleted according to the TAG
#   ---------------------------------------------------
    $msg="Step 1 : List of objets to be deleted ...\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "list backup summary completed before 'SYSDATE-$RET';\n";
    print CMD "release channel;\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC=&RMAN_Command($cmd,1);          # Launch RMAN Command.

    if ($RC != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [delete_obsolete_tag] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

#   Sample of Result of "list backup" command :
#
#   Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
#   ------- -- -- - ----------- --------------- ------- ------- ---------- ---
#   6       B  F  A SBT_TAPE    17-APR-12       1       1       NO         DLY_BCF
#   8       B  F  A SBT_TAPE    17-APR-12       1       1       NO         DLY_BCF

    @tobedeleted=();                    # Init.
    $nbdelete=0;                        # Init.
    $msg="";
    $msg=$msg."List of the Backups which can be deleted :\n";

    open (TMP,"<$TMPFILE");

    while ($line=<TMP>)
        {
        $line=~s/\n$//;                 # On supprime le \n � la fin.
        $line=~s/ +$//;                 # On supprime les Espaces de la fin.
        if ($line =~ "SBT_TAPE")
            {
            $line=&trim($line);
            @tmp=split(" ",$line);
            $nb=scalar(@tmp);
            $ch=uc($tmp[$nb-1]);        # "TAG" Field.
            $tagmaj=uc($TAG);           # Test the Tag.
            if ($ch =~ $tagmaj)         # Only Selected Tags.
                {
                $key=$tmp[0];           # Key ID of the Backup.
                $nbdelete=$nbdelete+1;
                $tobedeleted[$nbdelete]=$key;
                $msg=$msg."$line\n";
                }
            }
        }

    close TMP;

    if ($nbdelete == 0)
        {
        $msg="!!!  Nothing to delete for Tag $TAG, Exit";
        &Trace($msg);
        $RC=0;
        return;
        }

    $msg=$msg."\n";
    $msg=$msg."Number of Backups found : $nbdelete\n";
    $msg=$msg."\n";
    &Trace($msg);

#   2 - Control if we have backups after the deletion we asked to perform
#   ---------------------------------------------------------------------
    $msg="Step 2 : Control if we have backups after the deletion ...\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "list backup summary completed after 'SYSDATE-$RET';\n";
    print CMD "release channel;\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC=&RMAN_Command($cmd,1);          # Launch RMAN Command.

    if ($RC != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [delete_obsolete_tag] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    $chk=0;                             # Init Flag.
    open (TMP,"<$TMPFILE");
    while ($line=<TMP>)
        {
        $line=~s/\n$//;                 # On supprime le \n � la fin.
        $line=~s/ +$//;                 # On supprime les Espaces de la fin.
        if ($line =~ "SBT_TAPE") {$chk=1;}
        }

    close TMP;

    if ($chk == 0)
        {
        $msg="";
        $msg=$msg."/!\ You attempt to delete the last backup registered, abort the deletion process for $ORACLE_SID,\n";
        $msg=$msg."Tag $TAG, Retention $RETENTION_OR_FSUSAGE\n";
        &Trace($msg);
        $RC=28;
        return;
        }

#   3 - Check Child / Father Consistency
#   ------------------------------------
    $msg="Step 3 : Check Child / Father Consistency ...\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "list backup summary;\n";
    print CMD "release channel;\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC=&RMAN_Command($cmd,0);          # Launch RMAN Command.

    if ($RC != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [delete_obsolete_tag] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    @LV0=();                            # List of Levels 0.
    $nblv0=0;                           # Counter of Levels 0.
    $nbrel=0;
    $FLAG=0;
    $LASTLV0="";

    $msg="";
    $msg=$msg."Child / Father Consistency List :\n";

    open (TMP,"<$TMPFILE");
    while ($line=<TMP>)
        {
        $line=~s/\n$//;                 # On supprime le \n � la fin.
        $line=~s/ +$//;                 # On supprime les Espaces de la fin.
        if ($line !~ "SBT_TAPE") {next;}

        $line=&trim($line);
        $msg=$msg."$line\n";

        $nbrel=$nbrel+1;
        @tmp=split(" ",$line);
        $key=$tmp[0];                   # Key ID of the Backup.
        $LV=$tmp[2];                    # Level (0, 1, 2, A, F).
        $nb=scalar(@tmp);
        $ch=uc($tmp[$nb-1]);            # "TAG" Field.

        $ok=0;
        if ($LV eq "0" && $ch =~ "BDB") {$ok=1;}    # It's a Level 0
        if ($LV eq "F" && $ch =~ "BDB") {$ok=1;}    # It's a Level 0.
        if ($ok == 1)                   # It's a Level 0 "BDB" or Level F "BDB".
            {
            if ($FLAG == 0)
                {
                $LASTLV0="";
                $FLAG=1;
                }

            if ($FLAG == 1)
                {
                $LASTLV0=$LASTLV0.$key." ";
                }
            $msg=$msg."---> LASTLV0=$LASTLV0\n";
            }

        if ($ch !~ "BDB") {$FLAG=0;}

        $ok=0;
        if ($LV eq "1" && $ch =~ "BDB") {$ok=1;}    # It's a Level 1.
        if ($LV eq "2" && $ch =~ "BDB") {$ok=1;}    # It's a Level 2.

        if ($ok == 1 && $LASTLV0 ne "")
            {
            $LASTLV0=&trim($LASTLV0);
            @tmp=split(" ",$LASTLV0);
            $nb=scalar(@tmp);
            for $i (1..$nb)
                {
                $nblv0=$nblv0+1;
                $key=$tmp[$i-1];
                $LV0[$nblv0]=$key;
                }
            }
        }

    close TMP;

    if ($nbrel == 0)
        {
        $msg="No found Relations Child / Father, Exit";
        &Trace($msg);
        $RC=0;
        return;
        }

   $msg=$msg."\n";

   if ($nblv0 > 0)
        {
        $msg=$msg."Level 0 found :\n";
        for $lv (1..$nblv0)
            {
            $msg=$msg."  $lv : $LV0[$lv]\n";
            }
        }

    $msg=$msg."\n";
    &Trace($msg);

#   4 - Deletion
#   ------------
    $msg="Step 4 : Delete obsolte Tags ...\n";
    &Trace($msg);

    $BSLIST="";

    for $i (1..$nbdelete)
        {
        $key=$tobedeleted[$i];          # Backup ID.
        $del=1;                         # Init DELETE Flag.
        if ($nblv0 > 0)
            {
            for $lv (1..$nblv0)
                {
                if ($key == $LV0[$lv])  # It's a Level 0 ...
                    {
                    $del=0;             # Cannot Delete.
                    }
                }
            }

        if ($del == 1) {$BSLIST=$BSLIST.$key.",";}
        }

    chop($BSLIST);

    if ($BSLIST ne "")
        {
        $msg="";
        $msg=$msg."\n";
        $msg=$msg."List of Backups to Delete :\n";
        $msg=$msg.$BSLIST."\n";
        &Trace($msg);

        open(CMD,">$cmdfile");
        print CMD "allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
        print CMD "delete noprompt backupset $BSLIST;\n";
        print CMD "release channel;\n";
        print CMD "exit;\n";
        close CMD;

        $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
        $RC=&RMAN_Command($cmd,1);          # Launch RMAN Command.

        if ($RC != 0)
            {
            $msg="RMAN Command Error $RC. Exit Sub [delete_obsolete_tag] ...\n\n";
            &Trace($msg);
            $RC=100;                        # RMAN Error.
            return;
            }

        &CreateTimestamp;
        $msg="";
        $msg=$msg."<== Deletion of BackupSets ended with RC $RC : $timestamp\n";
        $msg=$msg."<== Number of days : $RETENTION_OR_FSUSAGE\n";
        &Trace($msg);
        $RC=0;
        }
    }

# 4 - function delete_obsolete_days -
# ===================================
sub delete_obsolete_days
    {
    $msg="Delete obsolete days is no longer authorized, contact Storage Team.\n";
    &Trace($msg);
    $RC=1;
    return;

    &CreateTimestamp;
    $msg="";
    $msg=$msg."==> Beginning RMAN Delete Obsolete Backups in Days Retention : $timestamp\n";
    $msg=$msg."==> Number of days : $RETENTION_OR_FSUSAGE\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "delete noprompt force obsolete recovery window of $RETENTION_OR_FSUSAGE days;\n";

    print CMD "delete noprompt force obsolete recovery window of $RETENTION_OR_FSUSAGE days;\n";
    print CMD "release channel;\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC=&RMAN_Command($cmd,1);          # Launch RMAN Command.

    if ($RC != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [delete_obsolete_days] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &CreateTimestamp;
    $msg="";
    $msg=$msg."<== End of RMAN Delete Obsolete Days Retention Backups : $timestamp\n";
    $msg=$msg."<== Number of days : $RETENTION_OR_FSUSAGE\n";
    &Trace($msg);
    }

# 5 - function delete_obsolete_versions
# =====================================
sub delete_obsolete_versions
    {
    $msg="Delete obsolete days is no longer authorized, contact Storage Team.\n";
    &Trace($msg);
    $RC=1;
    return;

    &CreateTimestamp;
    $msg="";
    $msg=$msg."==> Beginning RMAN delete obsolete backups in versions retention : $timestamp\n";
    $msg=$msg."==> Number of versions : $RETENTION_OR_FSUSAGE\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "delete noprompt force obsolete redundancy $RETENTION_OR_FSUSAGE;\n";
    print CMD "delete noprompt force obsolete redundancy $RETENTION_OR_FSUSAGE;\n";
    print CMD "release channel;\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC=&RMAN_Command($cmd,1);          # Launch RMAN Command.

    if ($RC != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [delete_obsolete_versions] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &CreateTimestamp;
    $msg="";
    $msg=$msg."<== End of RMAN delete obsolete versions retention backups : $timestamp\n";
    $msg=$msg."<== Number of versions : $RETENTION_OR_FSUSAGE\n";
    &Trace($msg);
    }

# 6 - function backup_archivelog
# ==============================
sub backup_archivelog
    {
    &CreateTimestamp;
    $msg="==> Beginning RMAN Backup Archivelog : $timestamp\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "run {\n";
    print CMD "allocate channel t1 type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "configure controlfile autobackup OFF;\n";

    if ($LOG_RETENTION ne "")
        {
        print CMD "backup (archivelog all format='$FORMAT_ARCH.%d_%t_%s_%p' tag='$TAG_ARCH' not backed up);\n";
        print CMD "delete copy of archivelog all completed before 'SYSDATE-$LOG_RETENTION';\n";
        }
    else
        {
        print CMD "backup (archivelog all format='$FORMAT_ARCH.%d_%t_%s_%p' tag='$TAG_ARCH' delete input);\n";
        }

    print CMD "release channel t1;\n";
    print CMD "}\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC_KEEP=&RMAN_Command($cmd,1);     # Launch RMAN Command.

    if ($RC_KEEP != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [backup_archivelog] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &backup_controlfile;
    $RC=$RC_KEEP+$RC;

    &CreateTimestamp;
    $msg="<== End of RMAN Backup Archivelog : $timestamp\n";
    &Trace($msg);
    }

# 7 - function backup_archivelog_emergency
# ========================================
sub backup_archivelog_emergency
    {
    $ARCHIVELOGS_DIR="";                # Init.
    $PCTUSAGE="";                       # Init %Used.

#   - Looking for Oracle Archive Directory -
#   ----------------------------------------
    open(CMD,">$sqlfile");
    print CMD "set pagesize 0;\n";
    print CMD "set trimspool on;\n";
    print CMD "set feedback off;\n";
    print CMD "select value from v\$parameter where ";
    print CMD "(name='log_archive_dest' and value is not null) ";
    print CMD "or (name='log_archive_dest_1' and value is not null);\n";
    print CMD "exit\n";
    close CMD;

    if ($OS eq "AIX" || $OS eq "LINUX")
        {
        system ("chmod 755 $sqlfile");
        $cmdsh="";
        $cmdsh=$cmdsh."su - $ORA_USER -c \"";
        $cmdsh=$cmdsh.$profile."; ";
        $cmdsh=$cmdsh."export ORACLE_SID=$ORACLE_SID; ";
        $cmdsh=$cmdsh."sqlplus -s / as sysdba \@$sqlfile\" >$TMPFILE";
        system ($cmdsh);
        }

    if ($OS eq "MSWIN32")
        {
        $cmd="sqlplus -s \"/ as sysdba\" \@$sqlfile\" >$TMPFILE";
        system ($cmd);
        }

    if (!-f $TMPFILE)
        {
        $msg="SQLPLUS Error on Archive Directory Query ...\n";
        &Trace($msg);
        $RC=255;
        return;
        }

    open (TMP,"<$TMPFILE");
    while ($line=<TMP>)
        {
        $line=~s/\n$//;                     # On supprime le \n � la fin.
        $line=~s/ +$//;                     # On supprime les Espaces de la fin.
        if ($line=~/^$/) {next;}            # Ligne Vide.
        if ($line =~ "LOCATION")
            {
            @tmp=split("=",$line);
            $ARCHIVELOGS_DIR=$tmp[1];       # Oracle Archive Directory.
            }
        else
            {
            $ARCHIVELOGS_DIR=$line;         # Oracle Archive Directory.
            }
        }
    close TMP;

    if ($ARCHIVELOGS_DIR eq "")
        {
        $msg="Oracle Archive Directory Not Found ...\n";
        &Trace($msg);
        $RC=255;
        return;
        }

#   - Unix FileSystem Percentage Usage -
#   ------------------------------------
    if ($OS eq "AIX" || $OS eq "LINUX")
        {
        $cmd="df $ARCHIVELOGS_DIR >$TMPFILE";
        system ($cmd);

        if (-f $TMPFILE)
            {
            open (TMP,"<$TMPFILE");
            $nb=0;
            while ($line=<TMP>)
                {
                $line=~s/\n$//;             # On supprime le \n � la fin.
                $line=~s/ +$//;             # On supprime les Espaces de la fin.
                $nb=$nb+1;
                if ($nb == 2)
                    {
                    @tmp=split(" ",$line);
                    $PCTUSAGE=$tmp[3];      # % Used in the FileSystem.
                    chop($PCTUSAGE);        # Supress "%".
                    }
                }
            close TMP;
            }

        if ($PCTUSAGE eq "")
            {
            $msg="Cannot determine Oracle Archive Directory %Used ...\n";
            &Trace($msg);
            $RC=255;
            return;
            }

        $msg="";
        $msg=$msg."Oracle Archive Directory : $ARCHIVELOGS_DIR\n";
        $msg=$msg."%Used : $PCTUSAGE %\n";
        &Trace($msg);

        if ($PCTUSAGE < $RETENTION_OR_FSUSAGE)
            {
            $msg="Archive Logs Directory usage is $PCTUSAGE %, which is less than $RETENTION_OR_FSUSAGE ...\n";
            &Trace($msg);
            $RC=0;
            return;
            }
        }

#   - Windows Free Space -
#   -----------------------
    if ($OS eq "MSWIN32")
        {
        $cmd="dir /-C $ARCHIVELOGS_DIR >$TMPFILE";
        system ($cmd);

        if (-f $TMPFILE)
            {
            open (TMP,"<$TMPFILE");
            while ($line=<TMP>)
                {
                $line=~s/\n$//;                 # On supprime le \n � la fin.
                $line=~s/ +$//;                 # On supprime les Espaces de la fin.
                if ($line =~ "free")
                    {
                    $line=&trim($line);
                    @tmp=split(" ",$line);
                    $nb=scalar(@tmp);
                    $PCTUSAGE=$tmp[$nb-3];      # Free Space on Disk.
                    }
                }
            close TMP;
            }

        if ($PCTUSAGE eq "")
            {
            $msg="Cannot determine Free Space on disk ...\n";
            &Trace($msg);
            $RC=255;
            return;
            }

        $msg="";
        $msg=$msg."Oracle Archive Directory : $ARCHIVELOGS_DIR\n";
        $msg=$msg."Disk Free Space : $PCTUSAGE bytes\n";
        &Trace($msg);

        if ($PCTUSAGE > $RETENTION_OR_FSUSAGE)
            {
            $msg="Disk Free Space is $PCTUSAGE bytes, which is greater than $RETENTION_OR_FSUSAGE ...\n";
            &Trace($msg);
            $RC=0;
            return;
            }
        }

#   - RMAN backup archivelog -
#   --------------------------
    &CreateTimestamp;
    $msg="";
    $msg=$msg."==> Beginning RMAN Backup Archivelog Emergency because FS is greater than ${RETENTION_OR_FSUSAGE} : $timestamp\n";
    $msg=$msg."==> Calling standard backup_archivelog function ...\n";
    &Trace($msg);

    &backup_archivelog;
    &CreateTimestamp;

    $msg="<== End of RMAN Backup Archivelog Emergency : $timestamp\n";
    &Trace($msg);
    }

# 8 - function backup_controlfile
# ===============================
sub backup_controlfile
    {
    &CreateTimestamp;
    $msg="==> Beginning RMAN Backup Controlfile : $timestamp\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "run {\n";
    print CMD "allocate channel t1 type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "configure controlfile autobackup OFF;\n";
    print CMD "backup (current controlfile format='$FORMAT_CTL.%d_%t_%s_%p' tag='$TAG_CTL');\n";
    print CMD "release channel t1;\n";
    print CMD "}\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC=&RMAN_Command($cmd,1);          # Launch RMAN Command.

    if ($RC != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [backup_controlfile] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &CreateTimestamp;
    $msg="<== End of RMAN Backup Controlfile : $timestamp\n";
    &Trace($msg);
    }

# 9 - function backup_spfile
# ==========================
sub backup_spfile
    {
    if ($SPFILE == 0)                   # No SPFILE Usage.
        {
        $msg="NO SPFILE USAGE (RC=30)\n";
        &Trace($msg);
        $RC=30;
        return;
        }

    &CreateTimestamp;
    $msg="==> Beginning RMAN Backup Spfile : $timestamp\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "run {\n";
    print CMD "configure controlfile autobackup OFF;\n";
    print CMD "allocate channel t1 type 'sbt_tape' parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "configure controlfile autobackup OFF;\n";
    print CMD "backup (spfile format='$FORMAT_SPF.%d_%t_%s_%p' tag='$TAG_SPF');\n";
    print CMD "release channel t1;\n";
    print CMD "}\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC=&RMAN_Command($cmd,1);          # Launch RMAN Command.

    if ($RC != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [backup_spfile] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &CreateTimestamp;
    $msg="<== End of RMAN Backup Spfile : $timestamp\n";
    &Trace($msg);
    }

# 10 - function backup_db_inc0_mount
# ==================================
sub backup_db_inc0_mount
    {
    $msg="$MONITORING_STOP\n";
    &Trace($msg);
    &stopdatabase;                      # Stop Database.

    &CreateTimestamp;
    $msg="==> Beginning RMAN Backup Database Incremental Level 0 Mount : $timestamp\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "run {\n";
    print CMD "allocate channel t1 type 'sbt_tape' maxpiecesize 256G parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "configure controlfile autobackup OFF;\n";
    print CMD "backup incremental level = 0 check logical ";
    print CMD "(database format='$FORMAT_INC_0_MOUNT.%d_%t_%s_%p' tag='$TAG_INC_0_MOUNT') ";
    print CMD "(current controlfile format='$FORMAT_CTL.%d_%t_%s_%p' tag='$TAG_CTL') ";
    if ($SPFILE == 1)
        {
        print CMD "(spfile format='$FORMAT_SPF.%d_%t_%s_%p' tag='$TAG_SPF');\n";
        }
    print CMD "release channel t1;\n";
    print CMD "}\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC_KEEP=&RMAN_Command($cmd,1);     # Launch RMAN Command.

    if ($RC_KEEP != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [backup_db_inc0_mount] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &startdatabase;                     # Start Database.

    $msg="$MONITORING_START\n";
    &Trace($msg);
    &backup_controlfile;
    $RC=$RC_KEEP+$RC;

    &CreateTimestamp;
    $msg="<== End of RMAN Backup Database Incremental Level 0 Mount : $timestamp\n";
    &Trace($msg);
    }

# 11 - function backup_db_inc1_mount
# ==================================
sub backup_db_inc1_mount
    {
    $msg="$MONITORING_STOP\n";
    &Trace($msg);
    &stopdatabase;                      # Stop Database.

    &CreateTimestamp;
    $msg="==> Beginning RMAN Backup Database Incremental Level 1 Mount : $timestamp\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "run {\n";
    print CMD "sql 'alter database backup controlfile to trace';\n";
    print CMD "allocate channel t1 type 'sbt_tape' maxpiecesize 32G parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "configure controlfile autobackup OFF;\n";
    print CMD "backup incremental level = 1 cumulative check logical ";
    print CMD "(database format='$FORMAT_INC_1_MOUNT.%d_%t_%s_%p' tag='$TAG_INC_1_MOUNT') ";
    print CMD "(current controlfile format='$FORMAT_CTL.%d_%t_%s_%p' tag='$TAG_CTL') ";
    if ($SPFILE == 1)
        {
        print CMD "(spfile format='$FORMAT_SPF.%d_%t_%s_%p' tag='$TAG_SPF');\n";
        }
    print CMD "release channel t1;\n";
    print CMD "}\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC_KEEP=&RMAN_Command($cmd,1);     # Launch RMAN Command.

    if ($RC_KEEP != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [backup_db_inc1_mount] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &startdatabase;                     # Start Database.

    $msg="$MONITORING_START\n";
    &Trace($msg);
    &backup_controlfile;
    $RC=$RC_KEEP+$RC;

    &CreateTimestamp;
    $msg="<== End of RMAN Backup Database Incremental Level 1 Mount : $timestamp\n";
    &Trace($msg);
    }

# 12 - function backup_db_inc0_open
# =================================
sub backup_db_inc0_open
    {
    &CreateTimestamp;
    $msg="==> Beginning RMAN Backup Database Incremental Level 0 Open : $timestamp\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "run {\n";
    print CMD "sql 'alter database backup controlfile to trace';\n";
    print CMD "allocate channel t1 type 'sbt_tape' maxpiecesize 256G parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "allocate channel t2 type 'sbt_tape' maxpiecesize 256G parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";  
  print CMD "configure controlfile autobackup OFF;\n";
    print CMD "backup incremental level = 0 check logical ";
    print CMD "(database format='$FORMAT_INC_0_OPEN.%d_%t_%s_%p' tag='$TAG_INC_0_OPEN') ";
    print CMD "(current controlfile format='$FORMAT_CTL.%d_%t_%s_%p' tag='$TAG_CTL') ";

    if ($SPFILE == 1)
        {
        print CMD "(spfile format='$FORMAT_SPF.%d_%t_%s_%p' tag='$TAG_SPF') ";
        }

    if ($LOG_RETENTION ne "")
        {
        print CMD "plus archivelog format='$FORMAT_ARCH.%d_%t_%s_%p' tag='$TAG_ARCH' not backed up;\n";
        print CMD "delete copy of archivelog all completed before 'SYSDATE-$LOG_RETENTION';\n";
        }
    else
        {
        print CMD "plus archivelog format='$FORMAT_ARCH.%d_%t_%s_%p' tag='$TAG_ARCH' delete input;\n";
        }

    print CMD "release channel t1;\n";
     print CMD "release channel t2;\n"; 
    print CMD "}\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
 

   $RC_KEEP=&RMAN_Command($cmd,1);     # Launch RMAN Command.

    if ($RC_KEEP != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [backup_db_inc0_open] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &backup_controlfile;
    $RC=$RC_KEEP+$RC;

    &CreateTimestamp;
    $msg="<== End of RMAN Backup Database Incremental Level 0 Open : $timestamp\n";
    &Trace($msg);
    }

# 13 - function backup_db_inc1_open
# =================================
sub backup_db_inc1_open
    {
    &CreateTimestamp;
    $msg="==> Beginning RMAN Backup Database Incremental Level 1 Open : $timestamp\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "run {\n";
    print CMD "sql 'alter database backup controlfile to trace';\n";
    print CMD "allocate channel t1 type 'sbt_tape' maxpiecesize 32G parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "configure controlfile autobackup OFF;\n";
    print CMD "backup incremental level = 1 cumulative check logical ";
    print CMD "(database format='$FORMAT_INC_1_OPEN.%d_%t_%s_%p' tag='$TAG_INC_1_OPEN') ";
    print CMD "(current controlfile format='$FORMAT_CTL.%d_%t_%s_%p' tag='$TAG_CTL') ";

    if ($SPFILE == 1)
        {
        print CMD "(spfile format='$FORMAT_SPF.%d_%t_%s_%p' tag='$TAG_SPF') ";
        }

    if ($LOG_RETENTION ne "")
        {
        print CMD "plus archivelog format='$FORMAT_ARCH.%d_%t_%s_%p' tag='$TAG_ARCH' not backed up;\n";
        print CMD "delete copy of archivelog all completed before 'SYSDATE-$LOG_RETENTION';\n";
        }
    else
        {
        print CMD "plus archivelog format='$FORMAT_ARCH.%d_%t_%s_%p' tag='$TAG_ARCH' delete input;\n";
        }

    print CMD "release channel t1;\n";
    print CMD "}\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC_KEEP=&RMAN_Command($cmd,1);     # Launch RMAN Command.

    if ($RC_KEEP != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [backup_db_inc1_open] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &backup_controlfile;
    $RC=$RC_KEEP+$RC;

    &CreateTimestamp;
    $msg="<== End of RMAN Backup Database Incremental Level 1 Open : $timestamp\n";
    &Trace($msg);
    }

# 14 - function backup_db_full_mount
# ==================================
sub backup_db_full_mount
    {
    $msg="$MONITORING_STOP\n";
    &Trace($msg);
    &stopdatabase;                      # Stop Database.

    &CreateTimestamp;
    $msg="==> Beginning RMAN Backup Database Full Mount : $timestamp\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "run {\n";
    print CMD "sql 'alter database backup controlfile to trace';\n";
    print CMD "allocate channel t1 type 'sbt_tape' maxpiecesize 32G parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "configure controlfile autobackup OFF;\n";
    print CMD "backup full check logical ";
    print CMD "(database format='$FORMAT_FULL_MOUNT.%d_%t_%s_%p' tag='$TAG_FULL_MOUNT') ";
    print CMD "(current controlfile format='$FORMAT_CTL.%d_%t_%s_%p' tag='$TAG_CTL') ";
    if ($SPFILE == 1)
        {
        print CMD "(spfile format='$FORMAT_SPF.%d_%t_%s_%p' tag='$TAG_SPF');\n";
        }
    print CMD "release channel t1;\n";
    print CMD "}\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC_KEEP=&RMAN_Command($cmd,1);     # Launch RMAN Command.

    if ($RC_KEEP != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [backup_db_full_mount] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &startdatabase;                     # Start Database.

    $msg="$MONITORING_START\n";
    &Trace($msg);
    &backup_controlfile;
    $RC=$RC_KEEP+$RC;

    &CreateTimestamp;
    $msg="<== End of RMAN Backup Database Full Mount : $timestamp\n";
    &Trace($msg);
    }

# 15 - function backup_db_full_open
# =================================
sub backup_db_full_open
    {
    &CreateTimestamp;
    $msg="==> Beginning RMAN Backup Database Full Open : $timestamp\n";
    &Trace($msg);

    open(CMD,">$cmdfile");
    print CMD "run {\n";
    print CMD "sql 'alter database backup controlfile to trace';\n";
    print CMD "allocate channel t1 type 'sbt_tape' maxpiecesize 32G parms 'ENV=(TDPO_OPTFILE=$TDPO_OPTFILE)';\n";
    print CMD "configure controlfile autobackup OFF;\n";
    print CMD "backup full check logical ";
    print CMD "(database format='$FORMAT_FULL_OPEN.%d_%t_%s_%p' tag='$TAG_FULL_OPEN') ";
    print CMD "(current controlfile format='$FORMAT_CTL.%d_%t_%s_%p' tag='$TAG_CTL') ";
    if ($SPFILE == 1)
        {
        print CMD "(spfile format='$FORMAT_SPF.%d_%t_%s_%p' tag='$TAG_SPF') ";
        }
    print CMD "plus archivelog format='$FORMAT_ARCH.%d_%t_%s_%p' tag='$TAG_ARCH' delete input;\n";
    print CMD "release channel t1;\n";
    print CMD "}\n";
    print CMD "exit;\n";
    close CMD;

    $cmd="$RMAN_CONNECTION cmdfile=$cmdfile";
    $RC_KEEP=&RMAN_Command($cmd,1);     # Launch RMAN Command.

    if ($RC_KEEP != 0)
        {
        $msg="RMAN Command Error $RC. Exit Sub [backup_db_full_open] ...\n\n";
        &Trace($msg);
        $RC=100;                        # RMAN Error.
        return;
        }

    &backup_controlfile;
    $RC=$RC_KEEP+$RC;

    &CreateTimestamp;
    $msg="<== End of RMAN Backup Database Full Open : $timestamp\n";
    &Trace($msg);
    }

# 16 - function check_database_corruption
# =======================================
sub  check_database_corruption
    {
    open(CMD,">$sqlfile");
    print CMD "select * from v\$backup_corruption;\n";
    print CMD "select * from v\$database_block_corruption;\n";
    print CMD "exit;\n";
    close CMD;
    &SQLPLUS_Command;
    }

# - RMAN Command -
# ================
sub RMAN_Command
    {
    local ($cmdrman,$output)=@_;        # Parameters.

    if (-f $TMPFILE) {unlink $TMPFILE;}

    if (-f $cmdfile)
        {
        $nbc=0;
        $msg="";
        $msg=$msg."\n";
        $msg=$msg."RMAN Commands :\n";
        $msg=$msg."---------------\n";
        open (RMA,"<$cmdfile");
        while ($line=<RMA>)
            {
            $line=~s/\n$//;             # On supprime le \n � la fin.
            $line=~s/ +$//;             # On supprime les Espaces de la fin.
            $nbc=$nbc+1;
            $msg=$msg."  $nbc : $line\n";
            }

        close RMA;
        $msg=$msg."\n";
        &Trace($msg);
        }

    if ($OS eq "AIX" || $OS eq "LINUX")
        {
        if (-f $cmdfile) {system ("chmod 755 $cmdfile")};

        $cmd="";
        $cmd=$cmd."su - $ORA_USER -c \"";
        $cmd=$cmd.$profile."; ";
        if ($ORACLE_HOME ne "")
            {
            $path=$ENV{'PATH'};         # Path.
            $cmd=$cmd."PATH=$ORACLE_HOME/bin:$path; ";
            }
        $cmd=$cmd."export ORACLE_SID=$ORACLE_SID; ";
        $cmd=$cmd."export ORACLE_HOME=$ORACLE_HOME; ";
        $cmd=$cmd."export DSM_CONFIG=$DSMI_ORC_CONFIG; ";
        $cmd=$cmd."export NLS_DATE_FORMAT='Mon DD YYYY HH24:MI:SS'; ";
        $cmd=$cmd."$cmdrman\" >$TMPFILE";
        }

    if ($OS eq "MSWIN32")
        {
        $cmd=$cmdrman. " >$TMPFILE";
        }

    system ($cmd);                      # Launch RMAN Command.
    $code=$?;                           # Return Code.

    if ($output == 1)                   # Display RMAN Output.
        {
        $msg="RMAN Command Result :\n";
        open (TMP,"<$TMPFILE");
        while ($line=<TMP>)
            {
            $line=~s/\n$//;             # On supprime le \n � la fin.
            $msg=$msg."$line\n";
            }
        close TMP;
        $msg=$msg."\n";
        &Trace($msg);
        }

    $msg="RMAN Return Code : $code\n\n";
    &Trace($msg);
    return $code;
    }

# - Stop Database -
# =================
sub stopdatabase
    {
    &CreateTimestamp;
    $msg="Shutdown of Oracle Database and Startup Mount : $timestamp\n";
    &Trace($msg);

    open(CMD,">$sqlfile");
    print CMD "shutdown immediate\n";
    print CMD "startup restrict\n";
    print CMD "shutdown immediate\n";
    print CMD "startup mount\n";
    print CMD "exit\n";
    close CMD;
    &SQLPLUS_Command;
    }

# - Start Database -
# ==================
sub startdatabase
    {
    &CreateTimestamp;
    $msg="Beginning Instance Opening and Block Corruption Checking : $timestamp\n";
    &Trace($msg);

    open(CMD,">$sqlfile");
    print CMD "alter database open;\n";
    print CMD "select * from v\$backup_corruption;\n";
    print CMD "exit\n";
    close CMD;
    &SQLPLUS_Command;
    }

# - SQLPLUS Command -
# ===================
sub SQLPLUS_Command
    {
    if (-f $TMPFILE) {unlink $TMPFILE;}

    if ($OS eq "AIX" || $OS eq "LINUX")
        {
        system ("chmod 755 $sqlfile");

        $cmd="";
        $cmd=$cmd."su - $ORA_USER -c \"";
        $cmd=$cmd.$profile."; ";
        $cmd=$cmd."export ORACLE_SID=$ORACLE_SID; ";
        if ($ORACLE_HOME ne "")
            {
            $cmd=$cmd. "export ORACLE_HOME=$ORACLE_HOME; ";
            }
        $cmd=$cmd."sqlplus / as sysdba \@$sqlfile\" ";
        $cmd=$cmd.">$TMPFILE";
        }

    if ($OS eq "MSWIN32")
        {
        $cmd="";
        $cmd=$cmd."sqlplus / as sysdba \@$sqlfile\" ";
        $cmd=$cmd.">$TMPFILE";
        }

    system ($cmd);

    $msg="SQLPLUS Log :\n";
    if (-f $TMPFILE)
        {
        open (TMP,"<$TMPFILE");
        while ($line=<TMP>)
            {
            $line=~s/\n$//;             # On supprime le \n � la fin.
            $msg=$msg."$line\n";
            }
        close TMP;
        }
    &Trace($msg);
    }

# - Timestamp -
# =============
sub CreateTimestamp
    {
    @today=localtime(time);
    $today[4]=$today[4]+1;
    $today[5]=$today[5]+1900;

    $tsec=sprintf("%02d",$today[0]);
    $tmin=sprintf("%02d",$today[1]);
    $theu=sprintf("%02d",$today[2]);
    $tday=sprintf("%02d",$today[3]);
    $tmon=sprintf("%02d",$today[4]);
    $tyea=$today[5];

    $timestamp=$tmon."/".$tday."/".$tyea."  ".$theu.":".$tmin.":".$tsec;
    }

# - TRIM -
# ========
# Suppression des blancs au d�but et � la fin.

sub trim
    {
    local ($arg)=@_;
    $arg=~s/^\s+//;
    $arg=~s/\s+$//;
    return $arg;
    }

# - Increment a Date -
# ====================
sub incrementdate
    {
    local ($inc)=@_;                    # Increment Value.

    local($sec,$min,$hour,$day,$month,$year)=localtime(time);
    $year=$year+1900;
    $month=$month+1;
    $current_time=time();
    $calc_time=$current_time + ($inc * 86400);

    local($sec,$min,$hour,$day,$month,$year)=localtime($calc_time);
    $year=$year+1900;
    $month=$month+1;
    $tday=sprintf("%02d",$day);
    $tmon=sprintf("%02d",$month);
    return ($tday,$tmon,$year);
    }

# - Trace LOG File -
# ==================
sub Trace
    {
    local($msg)=@_;
    print $msg;
    open (LOGF,">>$LOGFILE");
    print LOGF $msg;
    close(LOGF);
    }


