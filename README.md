# mariabackup wrapper
This script wraps mariabackup with some little automatisation. With the same script, only changes 1 parameters, a full or incremental or restoring last backup can be done. The backup are compressed with gzip and encrypted (encryption key have to be stored in ```mykey``` file).

## wrapper.sh
``` wrapper.sh -F|R|I [-d <dir>] [-r <num>] [-t <dir>] [-u <file>] [-p <file>] [-k <file>] ```
* ```-F```: process a full backup
* ```-I```: process an incremental backup
* ```-R```: restore to the latest backup
* ```-d```: backup directory. By default: /backup"
* ```-r```: retention: number of full backup to keep. By default: 7"
* ```-t```: working directory. By default: /restore"
* ```-u```: username file. Default /.myuser"
* ```-p```: password file. Default: /.mypasswd"
* ```-k```: encryption key file. Default /.mykey"

-u, -p and -k expect a file; these are 1 line file containing only the required information (username, password, or encryption key)

### full backup
``` $0 -F ```
a user (-u), a password (-p) and an encryption key (-k) have to be defined.

The script will make a backup named `full.gz.enc` in the backup directory (-d). If previous backups exists, it will increase the number of the previous backup by 1 and only keep the <retention> number of backup. The previous incremental backups will be removed too. 

### incremental backup
``` $0 -I ```
a user (-u), a password (-p) and an encryption key (-k) have to be defined.

The incremental backup will be done as "inc<id>.gz.enc" in the backup directory. If no full backup have been found, the script will run one instead of an incremental.


### restore
``` $0 -R ```

## docker image
the main goal of this image is to be run as a side-car container to a mariadb server instance. The datadir should be shared between both. It could also be possible to restore the last backup in an init container of the main mariadb container.

This image runs jobber (https://dshearer.github.io/jobber/) instead of cron for periodicall running wrapper.sh.

The container will be executed with user mysql (uid 999)

How to configure tasks can be found at https://dshearer.github.io/jobber/doc/v1.4/ .  The ".jobber" file is by default looked at `/home/mysql/.jobber`. The default file runs the `wrapper.sh` with default values.

Usage:
```
docker run --rm -it \
  -v <mariadb_datadir>:/var/lib/mysql \
  -v <backup_dir>:/backup \
  -v <myuser_file>:/.myuser \
  -v <mypasswd_file>:/.mypasswd \
  -v <mykey_file>:/.mykey
ybovard/mariabackup_wrapper:10.5
```
An incremental backup is made each hour and a full one is made each day at 00:30:00 00. This can be overwritten either by mounting a custom jobber file in `/home/mysql/.jobber` or by specifying the file in the argument of the container. Example:
```
docker run --rm -it \
  -v <mariadb_datadir>:/var/lib/mysql \
  -v <backup_dir>:/backup \
  -v <myuser_file>:/.myuser \
  -v <mypasswd_file>:/.mypasswd \
  -v <mykey_file>:/.mykey
  -v <jobber>:/opt/jobber
ybovard/mariabackup_wrapper:10.5 /opt/jobber
```
