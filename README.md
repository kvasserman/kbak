# kbak

**kbak** is a bash script designed to simplify creation of encrypted full and differential backups.

The primary motivation for this tool was the need for a simple way to create differential backups of large binary files or block devices (VM disk images or LVM volumes, for example) that can be encrypted and shipped to a cloud storage. But you can backup anything you can stream or turn into a file (files, directories, etc.): `tar c mydir1 mydir2 myfile | kbak`

As it is a shell script, it relies on multiple low level [tools](#credits) to do the heavy lifting, but it saves you from having to remember all the parameters to all the tools you have to invoke to do the job and adds some nice [features](#features) on the top.

# Features

- Full and Differential Backups of a file, block device or standard input
- Automatic payload compression with gzip or, optionally, with pigz for multiprocessing speedup of the backups [^pigz]
- Optional AES256 encryption of payload
- Automatic payload checksum and verification [^checksum] [^sum]
- Backup file header allows for quick information retrieval: unique id, timestamp, sha256 sum, key signature, reference backup id, etc.
- Unique backup IDs allow for aditional checking on restore: you can't restore differential backup by referencing a wrong full backup.
- Options to show progress of backup or to quiet script messages completely.
- Low memory and disk requirements (the whole process is streamed, so there are no large temporary files).
- Changes to the code are automatically tested to ensure they don't break backup and restore integrity of the backups.

# Installation

## Debian based distros (Ubuntu, etc,)

1. Download the deb package from the assets of the [latest release](https://github.com/kvasserman/kbak/releases/latest)
2. Install dependencies: `sudo apt-get install gzip pigz openssl pv xdelta3`
3. Install the package: `sudo dpkg -i kbak-x.x-xxxx-xx-xx-xxxxx.deb`
4. Run it: `kbak --help`

## Other Linux distros:

1. Download the tar.gz file from the assets of the [latest release](https://github.com/kvasserman/kbak/releases/latest)
2. Install dependencies: `sudo apt-get install gzip pigz openssl pv xdelta3`
3. Untar the file: `tar xzvf kbak-x.x-xxxx-xx-xx-xxxxx.tar.gz`
	- Optionally, copy or move kbak directory (or just the kbak script from it) to some other location
4. Run it: `./kbak --help`

## Usage

    kbak [options] [target]    

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

# Performance

Performance depends on many factors: disks performance, kind and number of processors, type of data being compressed, level of compression, whether encryption is used, etc. So all the numbers are purely anecdotal, but I'm able to compress and encrypt 500GB LVM volume (source and target are on SSDs, with about 120GB of real data on the source volume) in about 20 minutes (this is using 8 cores for compression with `--pigz 8` option).

Differential backups are slower, because the code have to both read, decompress and, optionally, decrypt the entire full backup reference file as well as process the source.

# Current Limitations

- Different keys for full and differential backups are not supported [^samekey]

# Credits

As it is a script, it's built on the top of other excellent low level tools:
- [gzip](https://www.gnu.org/software/gzip/) - GNU Gzip is a popular data compression program
- [pigz](https://zlib.net/pigz/) - pigz, which stands for parallel implementation of gzip, is a fully functional replacement for gzip that exploits multiple processors and multiple cores to the hilt when compressing data.
- [openssl](https://www.openssl.org/) - OpenSSL software - a robust, commercial-grade, full-featured toolkit for general-purpose cryptography and secure communication
- [xdelta3](https://github.com/jmacd/xdelta) - Xdelta version 3 is a C library and command-line tool for delta compression using VCDIFF/RFC 3284 streams
- [pv](http://ivarch.com/programs/pv.shtml) - Pipe Viewer is a terminal-based tool for monitoring the progress of data through a pipeline.
- [dd](https://git.savannah.gnu.org/cgit/coreutils.git/) - a coreutils tool to "convert and copy a file"
- [shunit2](https://github.com/kward/shunit2) - shUnit2 is a xUnit unit test framework for Bourne based shell scripts, and it is designed to work in a similar manner to JUnit, PyUnit, etc.

# License

GNU General Public License version 3.

# Footnotes

[^checksum]: Checksum is not written if the backup is sent to standard out.
[^sum]: Checksum verification requires the entire content of backup file(s) to be read.
[^full]: Full backup mode is default, so -f or --full can be omitted.
[^key]: Key is expected to be a valid RSA private key. It can be generated with `openssl genrsa -out private.pem 4096`.
[^samekey]: The same key must be used for full and differential backups.
[^pigz]: pigz with multiple cores can provide significant speed up on compression, but decompression is still single threaded and it doesn't help with restore or reading the full backup reference in diff mode.
