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

if [ -e ./calibredb ]; then
    CALIBREDB=./calibredb
else
    CALIBREDB=calibredb
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
    NBR_GOOD=$(ls ./HumbleBundleLibrary/"$DIR"/*.{epub,mobi,cbz,azw,pdb,prc} 2>/dev/null | wc -l)
    if [ "$NBR_GOOD" -ge "1" ]; then
	echo "Adding book: $DIR"
	$CALIBREDB --with-library ./CalibreLibrary/ --ignore "*.zip" --one-book-per-directory add ./HumbleBundleLibrary/"$DIR" "$@" &
	WAIT=$!
    else
	echo "Adding book: $DIR with title $BASENAME"
	$CALIBREDB --with-library ./CalibreLibrary/ add --ignore "*.zip" --title "$BASENAME" --one-book-per-directory ./HumbleBundleLibrary/"$DIR" "$@" &
	WAIT=$!
    fi
    wait "$WAIT"
    RETURN="$?"
    if [ "$RETURN" == "0" ]; then
	echo "$DIR" >> ./humble_bundle_to_calibre_done.dat
    elif [ "$STOP" == "1" ]; then
	wait "$WAIT"
	RETURN="$?"
	if [ "$RETURN" == "0" ]; then
	    echo "$DIR" >> ./humble_bundle_to_calibre_done.dat
	else
	    echo "$DIR|$RETURN" >> ./humble_bundle_to_calibre_err.dat
	fi
	exit 0
    else
	echo "$DIR|$RETURN" >> ./humble_bundle_to_calibre_err.dat
    fi
    done
)
echo "All folders processed"
