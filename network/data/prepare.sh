#!/usr/bin/env bash
DIR=$(dirname "$0")

declare -a FILES
while test $# -gt 0
do
    case "$1" in
        -osm19) FILES+=("melbourne.osm")
            ;;
        -melb) FILES+=("melbourne.sqlite")
            ;;
        -net) FILES+=("network.sqlite")
            ;;
        -gtfs19) FILES+=("gtfs_au_vic_ptv_20191004.zip")
            ;;
        -demx10) FILES+=("DEMx10EPSG28355.tif")
                        ;;
        -A) FILES=(
              "melbourne.osm"
              "melbourne.sqlite"
              "network.sqlite"
              "gtfs_au_vic_ptv_20191004.zip"
              "DEMx10EPSG28355.tif")
                        ;;
        --*) echo "bad option $1"
            ;;
        *) echo "Unkown option $1"
            ;;
    esac
    shift
done

echo "Downlaoding ${FILES[@]} ..."

for file in ${FILES[*]}; do
  from="https://cloudstor.aarnet.edu.au/plus/s/rLTlQJDRixhyan9/download?path=%2F&files=$file"
  to="$DIR/$file"
  if [ ! -f "$to" ] ; then
      CMD="wget -O \"$to\" \"$from\""; echo "$CMD" && eval "$CMD"
  else
    echo "Found $to so will use it"
  fi
done
