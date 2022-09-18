#!/bin/bash

if [ ! -e ./HumbleBundleLibrary ]; then
    echo "Please make a symbolic link named 'HumbleBundleLibrary' that points to where you want the Humble Bundle Library"
    echo "e.g., ln -s /path/where/library/is ./HumbleBundleLibrary"
    echo
    exit 1
fi

if [ ! -e ./CalibreLibrary ]; then
    echo "Please make a symbolic link named 'CalibreLibrary' that points to where you want the Calibre Library"
    echo "e.g., ln -s /path/where/library/is ./CalibreLibrary"
    echo
    exit 1
fi

STOP=0
trap "STOP=1" SIGINT

MANUAL="$1"
shift 1

(
    cd ./HumbleBundleLibrary
    trap '' SIGINT    
    if [ -z "$MANUAL" ]; then
	find . -maxdepth 3 -mindepth 3 -type f \( -name "*.pdf" -or -name "*.epub" -or -name "*.mobi" -or -name "*.cbz" -or -name "*.azw" -or -name "*.pdb" -or -name "*.prc" \) -print0 | xargs -0 -n 1 dirname | sort | uniq
    else
	echo "$MANUAL"
    fi
) | (
    trap "STOP=1" SIGINT
    while read DIR; do
    if grep -q "^$DIR\$" ./humble_bundle_to_calibre_done.dat; then
	#echo "Already done: $DIR"
	continue
    fi
    BASENAME=$(basename "$DIR" | tr -s " ")
    NBR_GOOD=$(ls "$DIR"/*.{epub,mobi,cbz,azw,pdb,prc} 2>/dev/null | wc -l)
    if [ "$NBR_GOOD" -ge "1" ]; then
	echo "Adding book: $DIR"
	calibredb --with-library ./CalibreLibrary/ --ignore "*.zip" --one-book-per-directory add "$DIR" "$@" &
	WAIT=$!
    else
	echo "Adding book: $DIR with title $BASENAME"
	calibredb --with-library ./CalibreLibrary/ add --ignore "*.zip" --title "$BASENAME" --one-book-per-directory "$DIR" "$@" &
	WAIT=$!
    fi
    wait "$WAIT"
    RETURN="$?"
    if [ "$RETURN" == "0" ]; then
	echo "$DIR" >> ./humble_bundle_to_calibre_done.dat
    fi
    if [ "$STOP" == "1" ]; then
	wait "$WAIT"
	if [ "$RETURN" == "0" ]; then
	    echo "$DIR" >> ./humble_bundle_to_calibre_done.dat
	fi
	exit 0
    fi
    done
)
echo "All folders processed"

