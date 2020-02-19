#!/bin/bash

DIR=$(dirname "$0")
WGET=wget

# check if wget exists else abort
command -v $WGET > /dev/null 2>&1 || { echo "Shell program '$WGET' not found, please install it first"; exit 0; }

function getfile() {
  url=$1
  tofile=$2
  if [ ! -f "$tofile" ] ; then
    printf "Downloading $url to $tofile\n"
    CMD="wget -O \"$tofile\" \"$url\""; echo "$CMD" && eval "$CMD"
  else
    printf "Found $tofile so will use it\n"
  fi
}

printf "\n"

getfile "https://cloudstor.aarnet.edu.au/plus/s/xFhjoeRqwx21aGr/download?path=%2Fscenarios%2Fmel2016_0.1&files=net.xml.gz" "$DIR/net.xml.gz"

getfile "https://cloudstor.aarnet.edu.au/plus/s/xFhjoeRqwx21aGr/download?path=%2Fscenarios%2Fmel2016_0.1&files=mel2016_0.1.xml.gz" "$DIR/mel2016_0.1.xml.gz"

getfile "https://cloudstor.aarnet.edu.au/plus/s/xFhjoeRqwx21aGr/download?path=%2Fscenarios%2Fmel2016_0.1&files=mel2016_0.1.via.legend.png" "$DIR/mel2016_0.1.via.legend.png"

getfile "https://cloudstor.aarnet.edu.au/plus/s/xFhjoeRqwx21aGr/download?path=%2Fscenarios%2Fmel2016_0.1&files=mel2016_0.1.via.mp4" "$DIR/mel2016_0.1.via.mp4"
