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

	$delta -s "$files/file.bin" "$backups/file.kbak"
	assertEquals "$delta call failed" 0 $?

	$delta --restore -s "$backups/file.kbak" "$backups/file.bin"
	assertEquals "$delta call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileStdInOut() {
	doHeader 'Testing backup and restore of one file from stdin'

	cat "$files/file.bin" | $delta > "$backups/file.kbak"
	assertEquals "$delta call failed" 0 $?

	cat "$backups/file.kbak" | $delta --restore > "$backups/file.bin"
	assertEquals "$delta call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileStdIn() {
	doHeader 'Testing backup and restore of one file from stdin'

	cat "$files/file.bin" | $delta "$backups/file.kbak"
	assertEquals "$delta call failed" 0 $?

	cat "$backups/file.kbak" | $delta --restore "$backups/file.bin"
	assertEquals "$delta call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileStdOut() {
	doHeader 'Testing backup and restore of one file from stdin'

	$delta -s "$files/file.bin" > "$backups/file.kbak"
	assertEquals "$delta call failed" 0 $?

	$delta --restore -s "$backups/file.kbak" > "$backups/file.bin"
	assertEquals "$delta call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

# function testBackupDirectory() {
# 	doHeader 'Testing backup and restore of one directory'

# 	$delta -s "$files" "$backups/files.kbak"
# 	assertEquals "$delta call failed" 0 $?

# 	$delta --restore -s "$backups/files.kbak" "$backups"
# 	assertEquals "$delta call failed" 0 $?

# 	assertEquals 'Restored files are different' "$(sha256sum "$files"/* | cut -d' ' -f1)" "$(sha256sum "$backups/$files"/* | cut -d' ' -f1)"
# 	assertEquals 'Restored files are different in sub' "$(sha256sum "$files"/sub/* | cut -d' ' -f1)" "$(sha256sum "$backups/$files"/sub/* | cut -d' ' -f1)"
# }

function testDiffBackupFile() {
	doHeader 'Testing differential backup and restore of one file'

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$delta -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$delta call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$delta -s "$backups/copy/file.bin" -dr "$backups/file.kbak" "$backups/file.diff.kbak"
	assertEquals "$delta call failed" 0 $?

	$delta --restore -s "$backups/file.diff.kbak" -r "$backups/file.kbak" "$backups/file-from-diff.bin"
	assertEquals "$delta call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"
}

function testDiffBackupDirectory() {
	doHeader 'Testing differential backup and restore of a directory'

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"

	$delta -s "$backups/copy" "$backups/files.kbak"
	assertEquals "$delta call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	echo "new text" >> "$backups/copy/text2.txt"
	echo "new text" >> "$backups/copy/sub/text3.txt"
	rm "$backups/copy/text.txt"

	$delta -s "$backups/copy" -dr "$backups/files.kbak" "$backups/files.diff.kbak"
	assertEquals "$delta call failed" 0 $?

	mkdir -p "$backups/diff"
	$delta --restore -s "$backups/files.diff.kbak" -r "$backups/files.kbak" "$backups/diff"
	assertEquals "$delta call failed" 0 $?

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

	$delta -s "$files/file.bin" -k "$key" "$backups/file.kbak"
	assertEquals "Full backup failed" 0 $?

	$delta --restore -s "$backups/file.kbak" -k "$key" "$backups/file.bin"
	assertEquals "Restore failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testBackupFileWithEncryptionWrongKey() {
	doHeader 'Testing backup and restore of one file with encryption'

	local key1="$backups/private1.key"
	local key2="$backups/private2.key"
	openssl genrsa -out "$key1" 4096
	openssl genrsa -out "$key2" 4096

	$delta -s "$files/file.bin" -k "$key1" "$backups/file.kbak"
	assertEquals "Full backup failed" 0 $?

	$delta --restore -s "$backups/file.kbak" -k "$key2" "$backups/file.bin"
	assertEquals "Restore didn't fail" 1 $?
}

function testBackupFileStdInOutWithEncryption() {
	doHeader 'Testing backup and restore of one file from stdin with encryption'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	cat "$files/file.bin" | $delta -k "$key" > "$backups/file.kbak"
	assertEquals "$delta call failed" 0 $?

	cat "$backups/file.kbak" | $delta --restore -k "$key" > "$backups/file.bin"
	assertEquals "$delta call failed" 0 $?

	assertEquals 'Restored file is different' "$(sha256sum "$files/file.bin" | cut -d' ' -f1)" "$(sha256sum "$backups/file.bin" | cut -d' ' -f1)"
}

function testDiffBackupFileWithEncryption() {
	doHeader 'Testing differential backup and restore of one file with encryption'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"
	
	$delta -k "$key" -s "$backups/copy/file.bin" "$backups/file.kbak"
	assertEquals "$delta call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	
	$delta -k "$key" -s "$backups/copy/file.bin" -dr "$backups/file.kbak" "$backups/file.diff.kbak"
	assertEquals "$delta call failed" 0 $?

	$delta --restore -k "$key" -s "$backups/file.diff.kbak" -r "$backups/file.kbak" "$backups/file-from-diff.bin"
	assertEquals "$delta call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy/file.bin" | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/file-from-diff.bin" | cut -d' ' -f1)"

	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored file is different' "$sha1" "$sha2"

	# ls -l "$backups"
}

function testBackupDirectoryWithEncryption() {
	doHeader 'Testing backup and restore of one directory with encryption'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	$delta -k "$key" -s "$files" "$backups/files.kbak"
	assertEquals "$delta call failed" 0 $?

	$delta --restore -k "$key" -s "$backups/files.kbak" "$backups"
	assertEquals "$delta call failed" 0 $?

	assertEquals 'Restored files are different' "$(sha256sum "$files"/* | cut -d' ' -f1)" "$(sha256sum "$backups/$files"/* | cut -d' ' -f1)"
	assertEquals 'Restored files are different in sub' "$(sha256sum "$files"/sub/* | cut -d' ' -f1)" "$(sha256sum "$backups/$files"/sub/* | cut -d' ' -f1)"
}

function testDiffBackupDirectoryWithEncryption() {
	doHeader 'Testing differential backup and restore of a directory with encryption'

	local key="$backups/private.key"
	openssl genrsa -out "$key" 4096

	mkdir -p "$backups/copy"
	cp -r "$files"/* "$backups/copy/"

	$delta -k "$key" -s "$backups/copy" "$backups/files.kbak"
	assertEquals "$delta call failed" 0 $?

	dd conv=notrunc bs=1M count=2 seek=5 if=/dev/urandom of="$backups/copy/file.bin" status=none
	echo "new text" >> "$backups/copy/text2.txt"
	echo "new text" >> "$backups/copy/sub/text3.txt"
	rm "$backups/copy/text.txt"

	$delta -k "$key" -s "$backups/copy" -dr "$backups/files.kbak" "$backups/files.diff.kbak"
	assertEquals "$delta call failed" 0 $?

	mkdir -p "$backups/diff"
	$delta --restore -k "$key" -s "$backups/files.diff.kbak" -r "$backups/files.kbak" "$backups/diff"
	assertEquals "$delta call failed" 0 $?

	local sha1="$(sha256sum "$backups/copy"/* 2>/dev/null | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/diff/$backups/copy"/* 2>/dev/null | cut -d' ' -f1)"
	
	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored directory is different' "$sha1" "$sha2"

	local sha1="$(sha256sum "$backups/copy/sub"/* 2>/dev/null | cut -d' ' -f1)"
	local sha2="$(sha256sum "$backups/diff/$backups/copy/sub"/* 2>/dev/null | cut -d' ' -f1)"
	
	assertNotEquals 'sha is blank' "$sha1" ''
	assertEquals 'Restored sub-directory is different' "$sha1" "$sha2"
}

# function suite() {
# 	# suite_addTest testBackupFile
# 	# suite_addTest testBackupFileWithEncryption
# 	suite_addTest testDiffBackupFileWithEncryption
# }

fullpath="$(readlink -f "$0")"
relpath="$(realpath --relative-to=. "$fullpath")"
mydir="$(dirname "$relpath")"

tempd="$(mktemp -d)"
files="$tempd/files"
backups="$tempd/backups"
delta="$(realpath --relative-to=. "$mydir/../kbak")"

. shunit2

