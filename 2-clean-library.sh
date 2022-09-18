#!/bin/bash

if [ ! -e ./HumbleBundleLibrary ]; then
    echo "Please make a symbolic link named 'HumbleBundleLibrary' that points to where you want the Humble Bundle Library"
    echo "e.g., ln -s /path/where/library/is ./HumbleBundleLibrary"
    echo
    exit 1
fi

mkdir -p rmlint
cd rmlint

echo "Look for empty dirs - investigate manually"
rmlint --types "emptyfiles,emptydirs"  -o pretty:stdout ../HumbleBundleLibrary

echo "Look for duplicated dirs"
rmlint --types "dd" --merge-directories --honour-dir-layout -o progressbar -o sh:rmlint.sh -o pretty:stdout -o summary:stdout -o json:rmlint.json ../HumbleBundleLibrary

#rmlint "df,dd"
