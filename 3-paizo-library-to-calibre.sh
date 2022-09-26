#!/bin/bash

if [ ! -e ./PaizoLibrary ]; then
    echo "Please make a symbolic link named 'PaizoLibrary' that points to where you want the Paizo Library"
    echo "e.g., ln -s /path/where/library/is ./PaizoLibrary"
    echo
    exit 1
fi

if [ ! -e ./CalibreLibraryRPG ]; then
    echo "Please make a symbolic link named 'CalibreLibraryRPG' for your Calibre RPG Library."
    echo "e.g., ln -s /path/where/library/is ./CalibreLibraryRPG"
    echo
    exit 1
fi

if [ -e ./calibredb ]; then
    CALIBREDB=./calibredb
else
    CALIBREDB=calibredb
fi

touch ./paizo_to_calibre_done.dat
touch ./paizo_to_calibre_err.dat

if [ -e ./calibredb ]; then
    CALIBREDB=./calibredb
else
    CALIBREDB=calibredb
fi

STOP=0
#trap "STOP=1" SIGINT

MANUAL="$1"
shift 1

if $CALIBREDB --with-library ./CalibreLibraryRPG/ add_custom_column source "Source" "text" 2>/dev/null; then
    echo "Source custom column added to CalibreLibraryRPG"    
fi

touch ./paizo_to_calibre_done.dat

(
    cd ./PaizoLibrary
    #trap '' SIGINT    
    if [ -z "$MANUAL" ]; then
	find -L . -maxdepth 2 -mindepth 2 -type f \( -name "*.pdf" -or -name "*.epub" -or -name "*.mobi" -or -name "*.cbz" -or -name "*.azw" -or -name "*.pdb" -or -name "*.prc" \) -print
    else
	echo "$MANUAL"
    fi
) | (
  #trap "STOP=1" SIGINT
  while read DIR; do
      
      FILENAME=$(basename "$DIR" | tr -s " ")
      PRODUCTNAME=$(dirname "$DIR")
      PRODUCTNAME=$(basename "$PRODUCTNAME" | sed 's/ - Single File//' | tr -s " ")
      LIBRARY="./CalibreLibraryRPG"

      if grep -i -q "File per Chapter" <<< "$DIR" ; then
	  #echo "Single file version, skipping"
	  continue
      fi
      
      if grep -i -q "Lite" <<< "$DIR" ; then
	  #echo "Lite version, skipping"
	  continue
      fi
      
      if grep -i -q "GM Screen" <<< "$DIR" ; then
	  #echo "Lite version, skipping"
	  continue
      fi
      
      if grep -i -q "Lite" <<< "$DIR" ; then
	  #echo "Lite version, skipping"
	  continue
      fi
      
      if grep -i -q "Beginner Box" <<< "$DIR" ; then
	  #echo "Box, skipping"
	  continue
      fi    
      
      if grep -i -q "EXE.pdf" <<< "$DIR" ; then
	  #echo "Box, skipping"
	  continue
      fi    
      
      if grep -i -q "map" <<< "$DIR" ; then
	  #echo "Map, skipping"
	  continue
      fi

      if grep -i -q -- "-UnusualOrigins\.pdf" <<< "$DIR" ; then
	  #echo "Map, skipping"
	  continue
      fi

      if grep -i -q -- "-Chart\.pdf" <<< "$DIR" ; then
	  #echo "Map, skipping"
	  continue
      fi

      if grep -i -q " Pregens\.pdf" <<< "$DIR" ; then
	  #echo "Map, skipping"
	  continue
      fi

      if grep -i -q "Darkmoonvale\.pdf" <<< "$DIR" ; then
	  #echo "Map, skipping"
	  continue
      fi                        

      if grep -i -q "Flip-Mat" <<< "$DIR" ; then
	  #echo "Map, skipping"
	  continue
      fi          
      
      if grep -q "^$DIR\$" ./paizo_to_calibre_done.dat; then
	  #echo "== Already done"
	  continue
      fi

      echo "$PRODUCTNAME"
      #echo "==== PRODUCT: $PRODUCTNAME | LIB: $LIBRARY"
      
      #echo $CALIBREDB --with-library "$LIBRARY" add --ignore "*.zip" --title "$PRODUCTNAME" ./PaizoLibrary/"$DIR" "$@"
      
    OUTPUT=$($CALIBREDB --with-library "$LIBRARY" add --ignore "*.zip" --title "$PRODUCTNAME" --one-book-per-directory ./PaizoLibrary/"$DIR" "$@" 2> /tmp/err.out)
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
	    echo "Or add the following dir to: ./paizo_to_calibre_done.dat"
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

	# Keep the longest title
	if [ "${#TITLE}" -lt "${#PRODUCTNAME}" ]; then
	    TITLE="${PRODUCTNAME}"
	fi
	
	if [ -n "$TAGS" ]; then
	    TAGPREFIX="$(echo "$TAGS" | sed 's% / %,%g;'),"
	else
	    TAGPREFIX=""
	fi
	if grep -q -i "Pathfinder" <<< "$PRODUCTNAME"; then
	    TAGPREFIX="${TAGPREFIX}Pathfinder,"
	elif grep -q -i "Starfinder" <<< "$PRODUCTNAME"; then
	    TAGPREFIX="${TAGPREFIX}Starfinder,"	    
	fi
	echo "Updated metadata:"
	$CALIBREDB --with-library "$LIBRARY" set_metadata "$ID" -f "identifiers:${IDENTIFIERS_PREFIX}paizo:${PRODUCTNAME// /_}" -f "#source:Paizo: ${PRODUCTNAME}" -f "title:$TITLE" -f "tags:${TAGPREFIX}Paizo"
	RETURN3="$?"
    fi
    if [ "$RETURN" == "0" -a "$RETURN2" == "0" -a "$RETURN3" == "0" ]; then
	echo "$DIR" >> ./paizo_to_calibre_done.dat
    else
	echo "$DIR|$RETURN|$RETURN2|$RETURN3" >> ./paizo_to_calibre_err.dat
	echo "== Error handling book, aborting."
	exit 0
    fi
  done
)
echo "All folders processed"
