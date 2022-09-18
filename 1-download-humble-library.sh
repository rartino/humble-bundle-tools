#!/bin/bash

if [ ! -e ./simpleauth_cookie.dat ]; then
    echo "Please create a 'simpleauth_cookie.dat' file containing the contents of the _simpleauth_sess cookie when using"
    echo "the Humble Bundle website while logged in. Please see documentation of Humble Bundle Downloader for more info."
    echo
    exit 1
fi

if [ ! -e ./HumbleBundleLibrary ]; then
    echo "Please make a symbolic link named 'HumbleBundleLibrary' that points to where you want the Humble Bundle Library"
    echo "e.g., ln -s /path/where/library/is ./HumbleBundleLibrary"
    echo
    exit 1
fi

if [ -e ./hdb ]; then
    HDB="./hbd"
else
    HDB="hbd"
fi

$HDB -s "$(cat ./simpleauth_cookie.dat)" --library-path ./HumbleBundleLibrary --progress
