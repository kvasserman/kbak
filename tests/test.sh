#!/bin/bash

function doHeader() {
	printf "\e[A\e[K\n\e[36m${FUNCNAME[1]}\e[0m\n"
	[ -z "$1" ] || printf "$1\n---\n"
}

function oneTimeTearDown() {
	[ -d "$tempd" ] && rm -r "$tempd" 
}

function oneTimeSetUp() {
	oneTimeTearDown

	echo 'Creating files'
	mkdir -p "$files/sub"
	mkdir -p "$backups"

	echo "some text" > "$files/text.txt"
	echo "some text 2" > "$files/text2.txt"
	echo "some text 3" > "$files/sub/text3.txt"
	echo "hidden" > "$files/.hidden"
	dd bs=16M count=2 if=/dev/urandom of="$files/file.bin" status=none
}

function tearDown() {
	echo '---'
	rm -r "$backups"/* 2>/dev/null
}

function testBackupFile() {
	doHeader 'Testing backup and restore of one file'

	$kbak -s "$files/file.bin" "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	echo "Backup file info:"
	$kbak -s "$backups/file.kbak" --info
	echo ""

	$kbak --restore -s "$backups/file.kbak" "$backups/file.bin"
	assertEquals "$kbak call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileStdInOut() {
	doHeader 'Testing backup and restore of one file from stdin'

	cat "$files/file.bin" | $kbak > "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	cat "$backups/file.kbak" | $kbak --restore > "$backups/file.bin"
	assertEquals "$kbak call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileStdIn() {
	doHeader 'Testing backup and restore of one file from stdin'

	cat "$files/file.bin" | $kbak "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	cat "$backups/file.kbak" | $kbak --restore "$backups/file.bin"
	assertEquals "$kbak call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileStdOut() {
	doHeader 'Testing backup and restore of one file from stdin'

	$kbak -s "$files/file.bin" > "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	$kbak --restore -s "$backups/file.kbak" > "$backups/file.bin"
	assertEquals "$kbak call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupDirectory() {
	doHeader 'Testing backup and restore of one directory'

	tar -cS "$files" | $kbak "$backups/files.kbak"
	assertEquals "$kbak call failed" 0 $?

	$kbak --restore -s "$backups/files.kbak" | tar -xC "$backups"
	assertEquals "$kbak call failed" 0 $?

	assertEquals 'Restored files are different' "$(sha256sum "$files"/* | cut -d' ' -f1)" "$(sha256sum "$backups/$files"/* | cut -d' ' -f1)"
	assertEquals 'Restored files are different in sub' "$(sha256sum "$files"/sub/* | cut -d' ' -f1)" "$(sha256sum "$backups/$files"/sub/* | cut -d' ' -f1)"
}

function testDiffBackupFile() {
	doHeader 'Testing differential backup and restore of one file'

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$kbak -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	echo "Backup file info:"
	$kbak -s "$backups/file.kbak" --info
	echo ""

	$kbak --verify -s "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?
	echo ""

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$kbak -s "$backups/copy/file.bin" -dr "$backups/file.kbak" "$backups/file.diff.kbak"
	assertEquals "$kbak call failed" 0 $?

	assertTrue 'Diff is not smaller than full' "[ $(stat --printf='%s' "$backups/file.kbak") -gt $(stat --printf='%s' "$backups/file.diff.kbak") ]"

	echo "Diff file info:"
	$kbak -s "$backups/file.diff.kbak" --info
	echo ""

	echo "Verify diff file:"
	$kbak -s "$backups/file.diff.kbak" --verify
	echo ""

	$kbak --restore -s "$backups/file.diff.kbak" -r "$backups/file.kbak" "$backups/file-from-diff.bin"
	assertEquals "$kbak call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"
}

function testDiffBackupFileStreamRef() {
	doHeader 'Testing differential backup and restore of one file with streamed ref'

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$kbak -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$kbak -s "$backups/copy/file.bin" -dr <(cat "$backups/file.kbak") "$backups/file.diff.kbak"
	assertEquals "$kbak call failed" 0 $?

	assertTrue 'Diff is not smaller than full' "[ $(stat --printf='%s' "$backups/file.kbak") -gt $(stat --printf='%s' "$backups/file.diff.kbak") ]"

	$kbak --restore -s "$backups/file.diff.kbak" -r <(cat "$backups/file.kbak") "$backups/file-from-diff.bin"
	assertEquals "$kbak call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"
}

function testDiffBackupFileWithCompLevel() {
	doHeader 'Testing differential backup and restore of one file'

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$kbak -9 -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	echo "Backup file info:"
	$kbak -s "$backups/file.kbak" --info
	echo ""

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$kbak -9 -s "$backups/copy/file.bin" -dr "$backups/file.kbak" "$backups/file.diff.kbak"
	assertEquals "$kbak call failed" 0 $?

	assertTrue 'Diff is not smaller than full' "[ $(stat --printf='%s' "$backups/file.kbak") -gt $(stat --printf='%s' "$backups/file.diff.kbak") ]"

	echo "Diff file info:"
	$kbak -s "$backups/file.diff.kbak" --info
	echo ""

	$kbak -9 --restore -s "$backups/file.diff.kbak" -r "$backups/file.kbak" "$backups/file-from-diff.bin"
	assertEquals "$kbak call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"
}

function testDiffBackupFileWithPigz() {
	doHeader 'Testing differential backup and restore of one file'

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$kbak --pigz 4 -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	echo "Backup file info:"
	$kbak -s "$backups/file.kbak" --info
	echo ""

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$kbak --pigz 4 -s "$backups/copy/file.bin" -dr "$backups/file.kbak" "$backups/file.diff.kbak"
	assertEquals "$kbak call failed" 0 $?

	assertTrue 'Diff is not smaller than full' "[ $(stat --printf='%s' "$backups/file.kbak") -gt $(stat --printf='%s' "$backups/file.diff.kbak") ]"

	echo "Diff file info:"
	$kbak -s "$backups/file.diff.kbak" --info
	echo ""

	$kbak --pigz 4 --restore -s "$backups/file.diff.kbak" -r "$backups/file.kbak" "$backups/file-from-diff.bin"
	assertEquals "$kbak call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"
}

function testDiffBackupDirectory() {
	doHeader 'Testing differential backup and restore of a directory'

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"

	tar -cS "$backups/copy" | $kbak "$backups/files.kbak"
	assertEquals "$kbak call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	echo "new text" >> "$backups/copy/text2.txt"
	echo "new text" >> "$backups/copy/sub/text3.txt"
	rm "$backups/copy/text.txt"

	tar -cS "$backups/copy" | $kbak -dr "$backups/files.kbak" "$backups/files.diff.kbak"
	assertEquals "$kbak call failed" 0 $?

	assertTrue 'Diff is not smaller than full' "[ $(stat --printf='%s' "$backups/files.kbak") -gt $(stat --printf='%s' "$backups/files.diff.kbak") ]"

	mkdir -p "$backups/diff"
	$kbak --restore -s "$backups/files.diff.kbak" -r "$backups/files.kbak" | tar -xC "$backups/diff"
	assertEquals "$kbak call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy"/* 2>/dev/null | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/diff/$backups/copy"/* 2>/dev/null | cut -d' ' -f1)"
	
	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored directory is different' "$sha1" "$sha2"

	local sha1="$(sha256sum "$backups/copy/sub"/* 2>/dev/null | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/diff/$backups/copy/sub"/* 2>/dev/null | cut -d' ' -f1)"
	
	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored sub-directory is different' "$sha1" "$sha2"
}

function testBackupFileWithEncryption() {
	doHeader 'Testing backup and restore of one file with encryption'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	$kbak -s "$files/file.bin" -k "$key" "$backups/file.kbak"
	assertEquals "Full backup failed" 0 $?

	echo "Backup file info:"
	$kbak -s "$backups/file.kbak" --info
	echo ""

	$kbak --restore -s "$backups/file.kbak" -k "$key" "$backups/file.bin"
	assertEquals "Restore failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileWithEncryptionWrongKey() {
	doHeader 'Testing backup and restore of one file with encryption'

	local key1="$backups/private1.key"
	local key2="$backups/private2.key"
	openssl genrsa -out "$key1" 4096
	openssl genrsa -out "$key2" 4096

	$kbak -s "$files/file.bin" -k "$key1" "$backups/file.kbak"
	assertEquals "Full backup failed" 0 $?

	$kbak --restore -s "$backups/file.kbak" -k "$key2" "$backups/file.bin"
	assertEquals "Restore didn't fail" 1 $?
}

function testBackupFileStdInOutWithEncryption() {
	doHeader 'Testing backup and restore of one file from stdin with encryption'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	cat "$files/file.bin" | $kbak -k "$key" > "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	cat "$backups/file.kbak" | $kbak --restore -k "$key" > "$backups/file.bin"
	assertEquals "$kbak call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testDiffBackupFileWithEncryption() {
	doHeader 'Testing differential backup and restore of one file with encryption'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$kbak -k "$key" -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	$kbak -k "$key" -s "$backups/file.kbak" --verify
	assertEquals "$kbak call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$kbak -k "$key" -s "$backups/copy/file.bin" -dr "$backups/file.kbak" "$backups/file.diff.kbak"
	assertEquals "$kbak call failed" 0 $?

	assertTrue 'Diff is not smaller than full' "[ $(stat --printf='%s' "$backups/file.kbak") -gt $(stat --printf='%s' "$backups/file.diff.kbak") ]"

	$kbak -k "$key" -s "$backups/file.diff.kbak" --verify
	assertEquals "$kbak call failed" 0 $?

	$kbak --restore -k "$key" -s "$backups/file.diff.kbak" -r "$backups/file.kbak" "$backups/file-from-diff.bin"
	assertEquals "$kbak call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"

	# ls -l "$backups"
}

function testDiffBackupFileWithEncryptionRefStream() {
	doHeader 'Testing differential backup and restore of one file with encryption and with streamed ref'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$kbak -k "$key" -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$kbak -k "$key" -s "$backups/copy/file.bin" -dr <(cat "$backups/file.kbak") "$backups/file.diff.kbak"
	assertEquals "$kbak call failed" 0 $?

	assertTrue 'Diff is not smaller than full' "[ $(stat --printf='%s' "$backups/file.kbak") -gt $(stat --printf='%s' "$backups/file.diff.kbak") ]"

	$kbak --restore -k "$key" -s "$backups/file.diff.kbak" -r <(cat "$backups/file.kbak") "$backups/file-from-diff.bin"
	assertEquals "$kbak call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"
}

function testDiffBackupFileWithEncryptionWithPigz() {
	doHeader 'Testing differential backup and restore of one file with encryption'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$kbak --pigz 4 -k "$key" -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$kbak --pigz 4 -k "$key" -s "$backups/copy/file.bin" -dr "$backups/file.kbak" "$backups/file.diff.kbak"
	assertEquals "$kbak call failed" 0 $?

	assertTrue 'Diff is not smaller than full' "[ $(stat --printf='%s' "$backups/file.kbak") -gt $(stat --printf='%s' "$backups/file.diff.kbak") ]"

	$kbak --pigz 4 --restore -k "$key" -s "$backups/file.diff.kbak" -r "$backups/file.kbak" "$backups/file-from-diff.bin"
	assertEquals "$kbak call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"

	# ls -l "$backups"
}

function testDiffBackupFileWithEncryptionWithPigzAndCompLevel() {
	doHeader 'Testing differential backup and restore of one file with encryption'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$kbak --pigz 4 -9 -k "$key" -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$kbak call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$kbak --pigz 4 -9 -k "$key" -s "$backups/copy/file.bin" -dr "$backups/file.kbak" "$backups/file.diff.kbak"
	assertEquals "$kbak call failed" 0 $?

	assertTrue 'Diff is not smaller than full' "[ $(stat --printf='%s' "$backups/file.kbak") -gt $(stat --printf='%s' "$backups/file.diff.kbak") ]"

	$kbak --pigz 4 -9 --restore -k "$key" -s "$backups/file.diff.kbak" -r "$backups/file.kbak" "$backups/file-from-diff.bin"
	assertEquals "$kbak call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"

	# ls -l "$backups"
}

# function suite() {
# 	suite_addTest testDiffBackupFileWithEncryptionRefStream
# }

fullpath="$(realpath "$0")"
mydir="$(dirname "$fullpath")"

tempd="$(mktemp -d)"
files="$tempd/files"
backups="$tempd/backups"
kbak="$(realpath "$mydir/../src/kbak")"

# echo "$kbak"

. shunit2

