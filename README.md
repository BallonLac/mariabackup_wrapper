/backup/restore: prepared to be restored
/backup/latest/full: latest full
/backup/latest/inc

process:
- full: 
    rm /backup/archive/full.7
    mv /backup/archive/full.6 /backup/archive/full.7
    mv /backup/archive/full.5 /backup/archive/full.6
    mv /backup/archive/full.4 /backup/archive/full.5
    mv /backup/archive/full.3 /backup/archive/full.4
    mv /backup/archive/full.2 /backup/archive/full.3
    mv /backup/archive/full.1 /backup/archive/full.2
    mv /backup/archive/full.0 /backup/archive/full.1
    mv /backup/latest/full /backup/archive/full.0
    mkdir /backup/latest/full
    rm -rf /backup/latest/inc*/*
    echo "0" > /backup/latest/next
    mariabackup --backup --targetdir=/backup/latest/full ...
    cp -rp /backup/latest/full /backup/restore.new
    mariabackup --prepare --targetdir=/backup/restore.new ...

    rm -rf /backup/restore
    mv /backup/restore.new /backup/restore

- inc:
    cur=`cat /backup/latest/next`
    echo `expr $cur + 1` > /backup/latest/next
    prev=`expr $cur - 1`
    if [ $next -eq 0 ]; then
      mariabackup --backup --target-dir=/backup/latest/inc0/ --incremental-basedir=/backup/latest/full ...
    else
      mariabackup --backup --target-dir=/backup/latest/inc${cur}/ --incremental-basedir=/backup/latest/inc${prev} ...
    fi
    mariabackup --prepare --target-dir=/backup/restore --incremental-dir=/backup/latest/inc${cur}
