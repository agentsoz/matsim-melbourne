#!/usr/bin/env bash

DIR=$(dirname "$0")

FILES=(
  "distanceMatrix.rds"
  "distanceMatrixIndex.csv"
  "sa1_2016_aust.csv.gz"
  "sa1_attributed.sqlite"
  "valid_addresses.sqlite"
)
ZIPS=(
  "melbourne-2016-population.zip"
  "vista_2012_16_v1_sa1_csv.zip"
)

# function to check if program exists
exists() {
  command -v "$1" >/dev/null 2>&1
}

### start here

# get all files
ALLFILES=("${FILES[@]}" "${ZIPS[@]}")
for file in ${ALLFILES[*]}; do
  from="https://cloudstor.aarnet.edu.au/plus/s/xFhjoeRqwx21aGr/download?path=%2Fdemand%2F2016&files=$file"
  to="$DIR/$file"
  if [ ! -f "$to" ] ; then
    if ! exists wget ; then
      echo "Please manually download $from to $to"
    else
      CMD="wget -O \"$to\" \"$from\""; echo "$CMD" && eval "$CMD"
    fi
  else
    echo "Found $to so will use it"
  fi
done

# unzip the archives
for file in ${ZIPS[*]}; do
  f=$DIR/$file
  d=$f.dir
  if [ -f "$f" ] ; then
    if ! exists unzip ; then
      printf "Please unzip the archive $f into directory $d\n"
    else
      CMD="mkdir -p $d && unzip -qo $f -d $d"; echo "$CMD" && eval "$CMD"
    fi
  fi
done
