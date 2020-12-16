#!/bin/sh
#set -e
#set -x

## TO DO: compression
## TO DO: encryption
## TO DO: doc

backupDir=/backup
retention=7
userfile=/.myuser
passfile=/.mypasswd

doPrepare(){
  dir=$1
  if [ ! -d $dir ]; then
    mkdir -p $dir;
    if [ ! $? -eq 0 ]; then echo "cannot make directory $dir"; exit 1; fi
  fi
  if [ ! -d $dir/archive ]; then
    mkdir -p $dir/archive;
    if [ ! $? -eq 0 ]; then echo "cannot make directory $dir/archive"; exit 1; fi
  fi
  if [ ! -d $dir/ready ]; then
    mkdir $dir/ready;
    if [ ! $? -eq 0 ]; then echo "cannot make directory $dir/ready"; exit 1; fi
  fi
  if [ ! -d $dir/latest ]; then
    mkdir $dir/latest;
    if [ ! $? -eq 0 ]; then echo "cannot make directory $dir/latest"; exit 1; fi
  fi
  if [ ! -f $dir/latest/next ]; then
    echo "0" > $dir/latest/next;
    if [ ! $? -eq 0 ]; then echo "cannot create file $dir/latest/next"; exit 1; fi
  fi
  #if [ ! -d $dir/latest/full ]; then mkdir -p $dir/latest/full; fi
  #if [ ! -d $dir/latest/inc0 ]; then mkdir -p $dir/latest/inc0; fi
}

doFull(){
  dir=$1
  retention=$2
  u=$3
  p=$4

  if [ -d $dir/archive/full.${retention} ]; then
    rm $dir/archive/full.${retention}
    if [ ! $? -eq 0 ]; then echo "cannot remove $dir/archive/full.${retention}"; exit 1; fi
  fi
  i=`expr $retention - 1`
  while [ $i -ge 0 ]; do
    if [ -d ${dir}/archive/full.${i} ]; then
      mv ${dir}/archive/full.${i} ${dir}/archive/full.`expr $i + 1`
      if [ ! $? -eq 0 ]; then echo "cannot rename $dir/archive/full.${i}"; exit 1; fi
    fi
    i=`expr $i - 1`
  done
  if [ -d ${dir}/latest/full ]; then
    mv ${dir}/latest/full ${dir}/archive/full.0
    if [ ! $? -eq 0 ]; then echo "cannot rename $dir/archive/full"; exit 1; fi
  fi
  
  mkdir ${dir}/latest/full
  if [ ! $? -eq 0 ]; then echo "cannot make $dir/latest/full"; exit 1; fi
  rm -rf ${dir}/latest/inc*
  if [ ! $? -eq 0 ]; then echo "cannot clean $dir/latest/inc directories"; exit 1; fi

  echo "0" > ${dir}/latest/next
  if [ ! $? -eq 0 ]; then echo "cannot reset counter in $dir/latest/next directories"; exit 1; fi

  mariabackup --backup --target-dir=${dir}/latest/full --user=$u --password=$p
  if [ ! $? -eq 0 ]; then echo "backup failed"; exit 1; fi

  if [ -d ${dir}/ready ]; then rm -rf ${dir}/ready.new; fi
  cp -rp ${dir}/latest/full ${dir}/ready.new

  mariabackup --prepare --target-dir=${dir}/ready.new
  if [ ! $? -eq 0 ]; then echo "restore preparation failed"; exit 1; fi

  rm -rf ${dir}/ready
  if [ ! $? -eq 0 ]; then echo "cannot clean $dir/ready directory"; exit 1; fi
  mv ${dir}/ready.new ${dir}/ready
  if [ ! $? -eq 0 ]; then echo "cannot rename $dir/ready.new"; exit 1; fi
}

doInc(){
  dir=$1
  u=$2
  p=$3

  cur=`cat ${dir}/latest/next`
  if [ ! $? -eq 0 ]; then echo "cannot read $dir/latest/next file"; exit 1; fi
  echo `expr $cur + 1` > ${dir}/latest/next
  if [ ! $? -eq 0 ]; then echo "cannot update $dir/latest/next file"; exit 1; fi

  if [ -d ${dir}/latest/inc${cur} ]; then
    rm -rf ${dir}/latest/inc${cur}
    if [ ! $? -eq 0 ]; then echo "cannot clean $dir/latest/inc directories"; exit 1; fi
  fi
  mkdir -p ${dir}/latest/inc${cur}
  if [ ! $? -eq 0 ]; then echo "cannot make $dir/latest/inc${cur} directory"; exit 1; fi

  if [ $cur -eq 0 ]; then
    incrementalBasedir=${dir}/latest/full
  else
    incrementalBasedir=${dir}/latest/inc`expr $cur - 1`
  fi
  mariabackup --backup --target-dir=${dir}/latest/inc${cur}/ --incremental-basedir=${incrementalBasedir} --user=$u --password=$p
  if [ ! $? -eq 0 ]; then echo "backup failed"; exit 1; fi

  mariabackup --prepare --target-dir=${dir}/ready --incremental-dir=${dir}/latest/inc${cur}
  if [ ! $? -eq 0 ]; then echo "restore preparation failed"; exit 1; fi
}

doRestore(){
  mariabackup --copy-back --target-dir=$1/ready
}

help(){
  echo "Usage:"
  echo "* full:        $0 -F"
  echo "* incremental: $0 -I"
  echo "* restore:     $0 -R"
  echo "Possible parameters:"
  echo "* -d: backup directory. By default: /backup"
  echo "* -r: retention: number of full backup to keep. By default: 7"
  echo "* -u: username file. Default /.myuser"
  echo "* -p: password file. Default: /.mypasswd"
}

ACTION="NA"

while getopts 'd:p:r:u:FIR' c; do
  case $c in
    d) if [ -d $OPTARG ]; then
         backupdir=$OPTARG 
       else
         echo "directory $OPTARG does not exist\n";
         help;
         exit 1;
       fi
       ;;
    r) retention=$OPTARG ;;
    u) if [ -f $OPTARG ]; then
         userfile=$OPTARG
       else
         echo "file $OPTARG does not exist or is not readable\n";
         help;
         exit 1;
       fi
       ;;
    p) if [ -f $OPTARG ]; then
         passfile=$OPTARG
       else
         echo "file $OPTARG does not exist or is not readable\n";
         help;
         exit 1;
       fi
       ;;
    F) if [ $ACTION = "NA" ]; then ACTION="FULL"; else help; exit 1; fi ;;
    I) if [ $ACTION = "NA" ]; then ACTION="INC"; else help; exit 1; fi ;;
    R) if [ $ACTION = "NA" ]; then ACTION="RESTORE"; else help; exit 1; fi ;;
    *) help; exit 1;;
  esac
done

if [ "$ACTION" = "NA" ]; then
  help
  exit 1
fi

echo "[`date`] directory structure preparation"
doPrepare $backupdir

echo "[`date`] get credentials"
user=""
if [ -f $userfile ]; then
  user=`cat $userfile`
fi

passwd=""
if [ -f $passfile ]; then
  passwd=`cat $passfile`
fi

echo "[`date`] run full backup"
if [ $ACTION = 'FULL' ]; then
  doFull $backupdir $retention $user $passwd
fi

echo "[`date`] run incremental backup"
if [ $ACTION = 'INC' ]; then
  doInc $backupdir $user $passwd
fi

echo "[`date`] run restore"
if [ $ACTION = 'RESTORE' ]; then
  doRestore $backupdir $restoreDir
fi

echo "[`date`] process ended"
exit 0
