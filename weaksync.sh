#!/bin/bash
#
#Weaksync is a tool to bring a network-mounted directory (e.g., dropbox, pcloud, sshfs, NFS, etc.) in sync with a local directory at a significantly reduced bandwidth cost. The tradeoff is that  changes that leaves a file the same size and still largely identical may not be propagated (even if the e.g., the ctime or filename has changed). This can happen e.g. if one edits fixed sized metadata fields in a media file. 
#
#Weaksync makes the most sense for things like media libraries of large files that occasionally gets reorganized and renamed, but where otherwise the file data is not expected to change. This is a situation where the bandwidth cost of checking every byte on the remote side of a moved file would be prohibitly large. 
#
#Rsync has a flag "--fuzzy" that provides a similar feature, especially together with '--size-only'. However, it only appears to check for renames in the same folder and when the filename is "similar", but with '--size-only' does not check any of the contents. Weaksync is more aggressive - it builds a database of all moderately large files on the receiving side and assumes any equally sized file where a specific 1000 byte segment overlaps is the same file. It is up to the user what strategy they are comfortable with in a certain scenario - but rsync's algorithm does generally not work well if one of the common changes are folder renames and inter-folder reorganization of files.

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <source> <dest> <reference>"
    exit 1
fi

SOURCE="$1"
DEST="$2"

if [ -n "$3" ]; then
    REF="$3"
else
    REF="$DEST"
fi
    
#COUNT=1

#if [ ! -e ~/.weaksync.dat ]; then

    echo "== Creating hash database"
    (
    cd "$REF"
    find . -type f -print | while read LINE; do
	BASENAME=$(basename "$LINE")
	SIZE=$(stat --printf="%s" "$LINE")
	if [ "$SIZE" -gt "50000" ]; then
	    HASH=$(sha1sum <(dd if="$LINE" bs=10000 count=1 skip=2 2>/dev/null) | awk '{print $1}')
	    echo "$HASH|$SIZE|$BASENAME|$LINE"
	fi
	#COUNT=$((COUNT+1))
	#if [ $COUNT -gt 100 ]; then
	#    break
	#fi
    done) | tee /tmp/cloud_file_database.dat
    echo "== Sorting database"
    cat /tmp/cloud_file_database.dat | sort > /tmp/cloud_file_database_sorted.dat
    echo "== Resolving unique hashes"
    cat /tmp/cloud_file_database_sorted.dat | awk -F"|" '{print $1}' | uniq -d > /tmp/non_unique.dat
    echo "== Removing non-unique hashes"
    if [ -s /tmp/non_unique.dat ]; then
	echo "Hash duplications found, removing"
	cat /tmp/cloud_file_database_sorted.dat | while read LINE; do
	    MATCH=$(echo "$LINE" | awk -F"|" '{print $1}')
	    if ! grep -q "^$MATCH\$" /tmp/non_unique.dat; then
		echo "$LINE"
	    fi
	done | tee ~/.weaksync.dat
    else
	mv /tmp/cloud_file_database_sorted.dat ~/.weaksync.dat
    fi
#fi

(
    cd "$SOURCE"
    find . -type f 
) | while read LINE; do
    echo "== Check: $LINE"
    SOURCESIZE=$(stat --printf="%s" "$SOURCE/$LINE")
    if [ -e "$DEST/$LINE" ]; then
	DESTSIZE=$(stat --printf="%s" "$DEST/$LINE")
	if [ "$DESTSIZE" == "$SOURCESIZE" ]; then
	    echo "Size match, ok"
	    continue
	fi
    fi
    DIRNAME=$(dirname "$LINE")
    if [ ! -d "$DEST/$DIRNAME" ]; then
	mkdir -p "$DEST/$DIRNAME"
    fi
    BASENAME=$(basename "$LINE")
    if [ "$SOURCESIZE" -gt "50000" ]; then
	HASH=$(sha1sum <(dd if="$SOURCE/$LINE" bs=10000 count=1 skip=2 2>/dev/null) | awk '{print $1}')
	echo "= Hash $HASH"
	DATAMATCH=$(grep "^$HASH|$SOURCESIZE|" ~/.weaksync.dat || true)
	if [ -n "$DATAMATCH" ]; then
	    MATCHFILE=$(echo "$DATAMATCH" | awk -F"|" '{print $4}')
	    echo "Match found!"
	    if [ -e "$REF/$MATCHFILE" ]; then
		mv "$REF/$MATCHFILE" "$DEST/$LINE"
	    else
		echo "File gone? Duplicate?"
		cp -p "$SOURCE/$LINE" "$DEST/$LINE"
	    fi
	else
	    echo "No match found in database, manual copy"
	    cp -p "$SOURCE/$LINE" "$DEST/$LINE"
	fi
    else
	cp -p "$SOURCE/$LINE" "$DEST/$LINE"	
    fi
done

echo "== Now handling primarily deletes using rsync"

rsync -av --delete --size-only /disks/Calibre/ /home/rar/pCloudDrive/Media/Books/Calibre/
