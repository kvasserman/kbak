# kbak

**kbak** is a bash script designed to simplify creating and restoring encrypted full and differential backups. 

## Usage

Available options:

    -f, --full                      full backup mode (default)
    -d, --diff, --differential      differential backup mode
    -x, --restore                   restore mode
        --info                      show information about kbak file
        --verify                    read source and verify it's integrity
    -r, --reference <full-backup>   full backup file to reference for differential backup/restore
    -s, --source <source>           source to backup. a file or a block device
                                    in restore mode source is full or diff kbak file
    -k, --key <rsa-private-key>     RSA private key file to encrypt/decrypt the backup         
        --pigz <N>                  Use pigz for compression (N is the number of processors to use)                   
    -1 to -9                        Compression level (default is 6)
    -p, --progress                  show progress
    -q, --quiet                     don't output normal messages (disables progress)
    -h, --help                      this help

## Examples

---

### Full backup

stdin backed up to stdout [^full]
> $ `cat myfile | kbak > myfile.kbak`

stdin backed up to stdout with progress
> $ `cat myfile | kbak -p > myfile.kbak`

full backup of a file or block device
> $ `kbak -s myfile myfile.kbak`

full backup of a directory (tar it first and pipe it into kbak)
> $ `tar -c mydir | kbak mydir.kbak`

full backup with encryption [^key]
> $ `kbak -s myfile -k private.pem myfile.kbak`

---

### Differential backup

differential backup of a file or block device
> $ `kbak -d -s myfile -r myfile.full.kbak myfile.diff.kbak`

differential backup of a file or block device with encryption [^samekey]
> $ `kbak -d -s myfile -r myfile.full.kbak -k private.pem myfile.diff.kbak`

---

### Restore

restore full backup
> $ `kbak -x -s myfile.full.kbak myfile.restored`

restore full backup of a directory (pipe it into tar)
> $ `kbak -x -s myfile.full.kbak | tar -xC mynewdir`

restore full backup with decryption [^key]
> $ `kbak -x -s myfile.full.kbak -k private.pem myfile.restored`

restore differential backup (requires reference to full backup)
> $ `kbak -x -s myfile.diff.kbak -r myfile.full.kbak myfile.restored`

restore differential backup with decryption [^samekey]
> $ `kbak -x -s myfile.diff.kbak -r myfile.full.kbak -k private.pem myfile.restored`

### Footnotes

[^full]: Full backup mode is default, so -f or --full can be ommited
[^key]: Key is expected to be a valid RSA private key. It can be generated with `openssl genrsa -out private.pem 4096`
[^samekey]: The same key must be used for full and differential backups (for right now)
