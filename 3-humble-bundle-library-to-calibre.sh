#!/bin/bash

#mkdir -p calibre-prefs
#export CALIBRE_CONFIG_DIRECTORY="$(cd calibre-prefs; pwd -P)"

#set -e

if [ ! -e ./HumbleBundleLibrary ]; then
    echo "Please make a symbolic link named 'HumbleBundleLibrary' that points to where you want the Humble Bundle Library"
    echo "e.g., ln -s /path/where/library/is ./HumbleBundleLibrary"
    echo
    exit 1
fi

if [ ! -e ./CalibreLibrary -o ! -e ./CalibreLibraryComics -o ! -e ./CalibreLibraryRPG ]; then
    echo "Please make symbolic links named 'CalibreLibrary', 'CalibreLibraryComics', 'CalibreLibraryRPG' for your Calibre Libraries."
    echo "(The links can point to the same folder if you want all these in the same library)"
    echo "e.g., ln -s /path/where/library/is ./CalibreLibrary"
    echo
    exit 1
fi

touch ./humble_bundle_to_calibre_done.dat
touch ./humble_bundle_to_calibre_err.dat

if [ -e ./calibredb ]; then
    CALIBREDB=./calibredb
else
    CALIBREDB=calibredb
fi

STOP=0
#trap "STOP=1" SIGINT

MANUAL="$1"
shift 1

if $CALIBREDB --with-library ./CalibreLibrary/ add_custom_column source "Source" "text" 2>/dev/null; then
    echo "Source custom column added to CalibreLibrary"
fi
if $CALIBREDB --with-library ./CalibreLibraryComics/ add_custom_column source "Source" "text" 2>/dev/null; then
    echo "Source custom column added to CalibreLibraryComics"    
fi
if $CALIBREDB --with-library ./CalibreLibraryRPG/ add_custom_column source "Source" "text" 2>/dev/null; then
    echo "Source custom column added to CalibreLibraryRPG"    
fi

(
    cd ./HumbleBundleLibrary
    #trap '' SIGINT    
    if [ -z "$MANUAL" ]; then
	find -L . -maxdepth 3 -mindepth 3 -path "./PRODUCTS/*" -prune -o -type f \( -name "*.pdf" -or -name "*.epub" -or -name "*.mobi" -or -name "*.cbz" -or -name "*.azw" -or -name "*.pdb" -or -name "*.prc" \) -print0 | xargs -0 -n 1 dirname | sort | uniq
    else
	echo "$MANUAL"
    fi
) | (
  #trap "STOP=1" SIGINT
  while read DIR; do

    ORIGDIR=$DIR
    PRODUCTNAME=$(basename "$DIR" | tr -s " ")
    PARENT=$(dirname "$DIR")
    BUNDLENAME=$(basename "$PARENT" | tr -s " ")
    if [ -L "./HumbleBundleLibrary/$DIR" ]; then
	DIR=$(readlink "./HumbleBundleLibrary/$DIR")
	DIR=${DIR#../}

	if [ ! -e ./HumbleBundleLibrary/"$DIR" ]; then
	    RAWPRODUCTNAME=$(basename "$DIR")
	    echo "HumbleBundleLibrary broken for:"
	    echo "  './HumbleBundleLibrary/$ORIGDIR'"
	    echo "Linked to non-existing:"
	    echo "  './HumbleBundleLibrary/$DIR'"
	    echo
	    exit 0
	fi
    fi
    
    LIBRARY="./CalibreLibrary"
    if grep -q "Comic" <<< "$BUNDLENAME"; then
	LIBRARY="./CalibreLibraryComics"
    elif grep -q "BOOM" <<< "$BUNDLENAME"; then
	LIBRARY="./CalibreLibraryComics"	
    elif grep -q "RPG" <<< "$BUNDLENAME"; then
	LIBRARY="./CalibreLibraryRPG"
    fi
    
    echo "==== BUNDLE: $BUNDLENAME | PRODUCT: $PRODUCTNAME | LIB: $LIBRARY"
    
    if grep -qxF "$DIR" ./humble_bundle_to_calibre_done.dat; then
	echo "== Already done"
	continue
    fi

    #NBR_GOOD=$(ls ./HumbleBundleLibrary/"$DIR"/*.{epub,mobi,cbz,azw,pdb,prc} 2>/dev/null | wc -l)

    OUTPUT=$($CALIBREDB --with-library "$LIBRARY" add --ignore "*.zip" --title "$BUNDLENAME" --one-book-per-directory ./HumbleBundleLibrary/"$DIR" "$@" 2> /tmp/err.out)
    RETURN="$?"
    echo "*** CALIBRE ERROR ***"
    cat /tmp/err.out
    echo "*** CALIBRE OUTPUT ***"
    echo "$OUTPUT"
    echo "**********************"
    echo "== RETURN CODE: $RETURN"
    if grep -q "already exist in the database" /tmp/err.out ; then
	EXISTING_TITLE=$(tail -n 1 /tmp/err.out | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	echo "== Already exists in database with title: $EXISTING_TITLE"
	ID=$($CALIBREDB --with-library "$LIBRARY" search "title:\"$EXISTING_TITLE\"")
	echo "Search gave id: $ID"
	if [[ "$ID" =~ ^[0-9]+$ ]]; then
	    echo "Existing metadata for ID: $ID"
	    $CALIBREDB --with-library "$LIBRARY" show_metadata "$ID"
	    echo 
	    echo "Consider:"
	    echo   "$CALIBREDB --with-library \"$LIBRARY\" remove \"$ID\""
	    echo
	    echo "Or add the following dir to: ./humble_bundle_to_calibre_done.dat"
	    echo "  $DIR"
	    exit 0
	else
	    echo "== Could dont extract ID of duplicate."
	    exit 0
	fi
    fi
   
    ID=$(echo "$OUTPUT" | sed -n 's/Added book ids: \([0-9]\+\)/\1/p')
    echo "Got ID: $ID"
    if ! [[ "$ID" =~ ^[0-9]+$ ]]; then
	echo "== Failed to extract id, perhaps something went wrong adding the book to the library?"
	exit 0
	continue
    else

	META=$($CALIBREDB --with-library "$LIBRARY" show_metadata "$ID")
	echo "Current metadata:"
	printf "%s\n\n" "$META"
	RETURN2="$?"
	#COMMENTS=$(echo "$META" | awk '/^Comments *:/ {DUMP=1} DUMP==1 {print}')
	#COMMENTS="${COMMENTS#*:}"
	IDENTIFIERS=$(echo "$META" | grep '^Identifiers *:')
	IDENTIFIERS="${IDENTIFIERS#*:}"
	TITLE=$(echo "$META" | grep '^Title *:')
	TITLE="${TITLE#*:}"
	TAGS=$(echo "$META" | awk -F": " '/^Tags/ {print $2}')
	if [ -n "$IDENTIFIERS" ]; then
	    IDENTIFIERS_PREFIX="$IDENTIFIERS,"
	else
	    IDENTIFIERS_PREFIX=""

	    IDENTIFIERS=
	fi
	#if [ -n "COMMENTS" ]; then
	#    COMMENTS="$COMMENTS
#
#Source: Humble Bundle - $BUNDLENAME / ${PRODUCTNAME}
#"
#	else
#	    COMMENTS="Source: Humble Bundle - $BUNDLENAME / ${PRODUCTNAME}"
#	fi

	# Keep the longest title
	if [ "${#TITLE}" -lt "${#PRODUCTNAME}" ]; then
	    TITLE="${PRODUCTNAME}"
	fi
	
	#if [ "$NBR_GOOD" == "0" ]; then
	#    TITLE="${PRODUCTNAME}"
	#fi

	if [ -n "$TAGS" ]; then
	    TAGPREFIX="$(echo "$TAGS" | sed 's% / %,%g;'),"
	else
	    TAGPREFIX=""
	fi
	echo "Updated metadata:"
	$CALIBREDB --with-library "$LIBRARY" set_metadata "$ID" -f "identifiers:${IDENTIFIERS_PREFIX}hb:${PRODUCTNAME// /_}" -f "#source:Humble Bundle: ${BUNDLENAME} / ${PRODUCTNAME}" -f "title:$TITLE" -f "tags:${TAGPREFIX}Humble Bundle"
	RETURN3="$?"
    fi
    if [ "$RETURN" == "0" -a "$RETURN2" == "0" -a "$RETURN3" == "0" ]; then
	echo "$DIR" >> ./humble_bundle_to_calibre_done.dat
    else
	echo "$DIR|$RETURN|$RETURN2|$RETURN3" >> ./humble_bundle_to_calibre_err.dat
	echo "== Error handling book, aborting."
	exit 0
    fi
    done
)
echo "All folders processed"
