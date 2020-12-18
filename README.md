# mariabackup wrapper

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

