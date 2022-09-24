#!/bin/bash

set -e

if [ ! -e ./HumbleBundleLibrary ]; then
    echo "Please make a symbolic link named 'HumbleBundleLibrary' that points to where you want the Humble Bundle Library"
    echo "e.g., ln -s /path/where/library/is ./HumbleBundleLibrary"
    echo
    exit 1
fi

cd ./HumbleBundleLibrary
mkdir -p PRODUCTS
find . -mindepth 2 -maxdepth 2 -type d -not -path "./PRODUCTS/*" | while read DIR; do
    echo "==== EXAMINING: $DIR"
    PRODUCT="$(basename "$DIR")"
    if [ -L "$DIR" ]; then
	echo "$DIR is already a symbolic link, leaving alone"
    elif [ -e "PRODUCTS/$PRODUCT" ]; then
	echo "== $PRODUCT already exists"
	if [ -n "$(ls -A "$DIR")" ]; then
	    for FILE in "$DIR"/*; do
		NAME="$(basename "$FILE")"
		if [ -e "PRODUCTS/$PRODUCT/$NAME" ]; then
		    echo "Same?" "$FILE" "PRODUCTS/$PRODUCT/$NAME"
		    if ! cmp --silent "$FILE" "PRODUCTS/$PRODUCT/$NAME"; then
			echo "SAME NAMED FILES ARE DIFFERENT?! ABORT!"
			exit 1
		    fi
		    echo "Product directory has duplicate files, overwriting"
		fi
		mv "$FILE" "PRODUCTS/$PRODUCT/$NAME"
	    done
	else
	    echo "Directory is empty, just replacing by symlink."
	fi
	rmdir "$DIR"
	ln -s "../PRODUCTS/$PRODUCT" "$DIR"
    else
	echo "== $PRODUCT does not already exist"
	mv "$DIR" "PRODUCTS/$PRODUCT"
	ln -s "../PRODUCTS/$PRODUCT" "$DIR"
	echo "Linked $DIR -> ../PRODUCTS/$PRODUCT"
    fi
done
