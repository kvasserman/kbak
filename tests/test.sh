#!/bin/bash

function doHeader() {
	printf "\e[A\e[K\n\e[36m${FUNCNAME[1]}\e[0m\n"
	[ -z "$1" ] || printf "$1\n---\n"
}

function oneTimeTearDown() {
	[ -d "$files" ] && rm -r "$files" 
	[ -d "$backups" ] && rm -r "$backups" 
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
	dd bs=16M count=2 if=/dev/zero of="$files/file.bin" status=none
}

function tearDown() {
	echo '---'
	rm -r "$backups"/* 2>/dev/null
}

function testBackupFile() {
	doHeader 'Testing backup and restore of one file'

	$delta -s "$files/file.bin" "$backups/file.bin.gz"
	$delta --restore -s "$backups/file.bin.gz" "$backups/file.bin"

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileStdInOut() {
	doHeader 'Testing backup and restore of one file from stdin'

	cat "$files/file.bin" | $delta > "$backups/file.bin.gz"
	cat "$backups/file.bin.gz" | $delta --restore > "$backups/file.bin"

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileStdIn() {
	doHeader 'Testing backup and restore of one file from stdin'

	cat "$files/file.bin" | $delta "$backups/file.bin.gz"
	cat "$backups/file.bin.gz" | $delta --restore "$backups/file.bin"

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileStdOut() {
	doHeader 'Testing backup and restore of one file from stdin'

	$delta -s "$files/file.bin" > "$backups/file.bin.gz"
	$delta --restore -s "$backups/file.bin.gz" > "$backups/file.bin"

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupDirectory() {
	doHeader 'Testing backup and restore of one directory'

	$delta -s "$files" "$backups/files.tar.gz"
	$delta --restore -s "$backups/files.tar.gz" "$backups"

	assertEquals 'Restored files are different' "$(sha256sum "$files"/* | cut -d' ' -f1)" "$(sha256sum "$backups/$files"/* | cut -d' ' -f1)"
	assertEquals 'Restored files are different in sub' "$(sha256sum "$files"/sub/* | cut -d' ' -f1)" "$(sha256sum "$backups/$files"/sub/* | cut -d' ' -f1)"
}

function testDiffBackupFile() {
	doHeader 'Testing differential backup and restore of one file'

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$delta -s "$backups/copy/file.bin" "$backups/file.bin.gz"

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$delta -s "$backups/copy/file.bin" -dr "$backups/file.bin.gz" "$backups/file.bin.diff.gz"

	$delta --restore -s "$backups/file.bin.diff.gz" -r "$backups/file.bin.gz" "$backups/file-from-diff.bin"

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"
}

function testDiffBackupDirectory() {
	doHeader 'Testing differential backup and restore of a directory'

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"

	$delta -s "$backups/copy" "$backups/files.tar.gz"

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	echo "new text" >> "$backups/copy/text2.txt"
	echo "new text" >> "$backups/copy/sub/text3.txt"
	rm "$backups/copy/text.txt"

	$delta -s "$backups/copy" -dr "$backups/files.tar.gz" "$backups/files.diff.gz"

	mkdir -p "$backups/diff"
	$delta --restore -p -s "$backups/files.diff.gz" -r "$backups/files.tar.gz" "$backups/diff"

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

	$delta -s "$files/file.bin" -k "$key" "$backups/file.dbak"
	assertEquals "Full backup failed" 0 $?

	$delta --restore -s "$backups/file.dbak" -k "$key" "$backups/file.bin"
	assertEquals "Restore failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"

	# ls -l "$backups"/
}

function suite() {
	# suite_addTest testBackupFile
	suite_addTest testBackupFileWithEncryption
}

fullpath="$(readlink -f "$0")"
relpath="$(realpath --relative-to=. "$fullpath")"
mydir="$(dirname "$relpath")"

files="$mydir/files"
backups="$mydir/backups"
delta="$(realpath --relative-to=. "$mydir/../delta-backup")"

. shunit2

