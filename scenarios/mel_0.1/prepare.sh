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

files=(
"plan.xml.gz"
"GMel_2D_IVABMPT_GMel_20m_MatsimCleanedCar_pnrAdded_v010.xml.gz"
)

for file in ${files[*]}; do
     getfile "https://cloudstor.aarnet.edu.au/plus/s/xFhjoeRqwx21aGr/download?path=%2Fscenarios%2Fmel_0.1&files=$file" "$DIR/$file"
done
