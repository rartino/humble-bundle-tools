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
rmlint --types "dd,df" --merge-directories --honour-dir-layout -o progressbar -o sh:rmlint-dd.sh -c sh:symlink -o pretty:stdout -o summary:stdout -o json:rmlint-dd.json ../HumbleBundleLibrary

echo "A script 'rmlint-dd.sh' has been created to remove and symlink duplicate directories."
echo "Inspect it and run it."
