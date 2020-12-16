#!/bin/sh
#set -e
#set -x

## TO DO: doc

tmpDir=/restore
backupDir=/backup
retention=7
userfile=/.myuser
passfile=/.mypasswd
keyfile=/.mykey

cleanDir(){
  t=$1
  if [ -d $t ]; then
    rm -rf $t
    if [ ! $? -eq 0 ]; then echo "cannot clean ${t}"; exit 1; fi
  fi
  mkdir -p $t
  if [ ! $? -eq 0 ]; then echo "cannot make directory ${t}"; exit 1; fi
}

doPrepare(){
  dir=$1
  if [ ! -d $dir ]; then
    mkdir -p $dir;
    if [ ! $? -eq 0 ]; then echo "cannot make directory $dir"; exit 1; fi
  fi
  if [ ! -f $dir/next ]; then
    echo "0" > $dir/next;
    if [ ! $? -eq 0 ]; then echo "cannot create file $dir/next"; exit 1; fi
  fi
}

doFull(){
  dir=$1
  retention=$2
  u=$3
  p=$4
  k=$5
  tmp=$6

  if [ -f $dir/full${retention}.gz.enc ]; then
    rm $dir/full${retention}.gz.enc
    if [ ! $? -eq 0 ]; then echo "cannot remove $dir/full${retention}.gz.enc"; exit 1; fi
  fi
  i=`expr $retention - 1`
  while [ $i -ge 0 ]; do
    if [ -f ${dir}/full${i}.gz.enc ]; then
      mv ${dir}/full${i}.gz.enc ${dir}/full`expr $i + 1`.gz.enc
      if [ ! $? -eq 0 ]; then echo "cannot rename $dir/full${i}.gz.enc"; exit 1; fi
    fi
    i=`expr $i - 1`
  done
  if [ -f ${dir}/full.gz.enc ]; then
    mv ${dir}/full.gz.enc ${dir}/full0.gz.enc
    if [ ! $? -eq 0 ]; then echo "cannot rename $dir/full.gz.enc"; exit 1; fi
  fi
  
  find ${dir}/inc*.gz.enc > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    rm ${dir}/inc*.gz.enc
    if [ ! $? -eq 0 ]; then echo "cannot clean incremental backups"; exit 1; fi
  fi

  echo "0" > ${dir}/next
  if [ ! $? -eq 0 ]; then echo "cannot reset counter in $dir/next"; exit 1; fi

  mariabackup --backup --user=$u --password=$p --stream=xbstream |gzip | openssl enc -aes-256-cbc -k $k > ${dir}/full.gz.enc
  if [ ! $? -eq 0 ]; then echo "backup failed"; exit 1; fi
}

doInc(){
  dir=$1
  u=$2
  p=$3
  k=$4
  tmp=$5

  cur=`cat ${dir}/next`
  if [ ! $? -eq 0 ]; then echo "cannot read $dir/next file"; exit 1; fi
  echo `expr $cur + 1` > ${dir}/next
  if [ ! $? -eq 0 ]; then echo "cannot update $dir/next file"; exit 1; fi

  if [ -f ${dir}/inc${cur}.gz.enc ]; then
    rm ${dir}/inc${cur}.gz.enc
    if [ ! $? -eq 0 ]; then echo "cannot clean ${dir}/inc${cur}.gz.enc"; exit 1; fi
  fi

  cleanDir $tmp

  if [ $cur -eq 0 ]; then
    cd $tmp
    openssl enc -d -aes-256-cbc -k $k -in ${dir}/full.gz.enc |gzip -d| mbstream -x
  else
    lastInc=${dir}/inc`expr $cur - 1`.gz.enc
    cd $tmp
    openssl enc -d -aes-256-cbc -k $k -in ${lastInc} |gzip -d| mbstream -x
  fi

  mariabackup --backup --incremental-basedir=${tmp} --user=$u --password=$p --stream=xbstream |gzip | openssl enc -aes-256-cbc -k $k > ${dir}/inc${cur}.gz.enc
  if [ ! $? -eq 0 ]; then echo "backup failed"; exit 1; fi
}

doRestore(){
  dir=$1
  k=$2
  tmp=$3

  next=`cat ${dir}/next`
  last=`expr $next - 1`

  cleanDir ${tmp}
  mkdir -p ${tmp}/ready
  mkdir -p ${tmp}/extract

  cd $tmp/ready
  openssl enc -d -aes-256-cbc -k $k -in ${dir}/full.gz.enc |gzip -d| mbstream -x
  cd ${tmp}
  mariabackup --prepare --target-dir=${tmp}/ready

  for i in `seq 0 1 ${last}`; do
    cleanDir "${tmp}/extract"

    cd ${tmp}/extract
    openssl enc -d -aes-256-cbc -k $k -in ${dir}/inc${i}.gz.enc |gzip -d| mbstream -x
    cd ${tmp}
    mariabackup --prepare --target-dir=${tmp}/ready --incremental-dir=${tmp}/extract
  done

  mariabackup --copy-back --target-dir=${tmp}/ready
}

help(){
  echo "Usage:"
  echo "* full:        $0 -F"
  echo "* incremental: $0 -I"
  echo "* restore:     $0 -R"
  echo "Possible parameters:"
  echo "* -d: backup directory. By default: /backup"
  echo "* -r: retention: number of full backup to keep. By default: 7"
  echo "* -t: working directory. By default: /restore"
  echo "* -u: username file. Default /.myuser"
  echo "* -p: password file. Default: /.mypasswd"
  echo "* -k: encryption key file. Default /.mykey"
}

ACTION="NA"

while getopts 'd:p:r:t:u:FIR' c; do
  case $c in
    d) if [ -d $OPTARG ]; then
         backupDir=$OPTARG 
       else
         echo "directory $OPTARG does not exist\n";
         help;
         exit 1;
       fi
       ;;
    r) retention=$OPTARG ;;
    t) tmpDir=$OPTARG ;;
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
    k) if [ -f $OPTARG ]; then
         keyfile=$OPTARG
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
doPrepare $backupDir

if [ ! "$ACTION" = "RESTORE" ]; then
  echo "[`date`] get credentials"
  user=""
  if [ -f $userfile ]; then
    user=`cat $userfile`
  fi
  if [ -z "$user" ]]; then echo "no user found"; help; exit 1; fi
  
  passwd=""
  if [ -f $passfile ]]; then
    passwd=`cat $passfile`
  fi
  if [ -z "$passwd" ]; then echo "no password found"; help; exit 1; fi
fi

key=""
if [ -f $keyfile ]]; then
  key=`cat $keyfile`
fi
if [ -z "$key" ]; then echo "no encryption key found"; help; exit 1; fi

if [ $ACTION = 'FULL' ]; then
  echo "[`date`] run full backup"
  doFull $backupDir $retention $user $passwd $key $tmpDir
fi

if [ $ACTION = 'INC' ]; then
  echo "[`date`] run incremental backup"
  doInc $backupDir $user $passwd $key $tmpDir
fi

if [ $ACTION = 'RESTORE' ]; then
  echo "[`date`] run restore"
  doRestore $backupDir $key $tmpDir
fi

echo "[`date`] process ended"
exit 0
