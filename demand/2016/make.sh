#!/usr/bin/env bash
if [ $# -ne 1 ];
    then printf "\nusage $0 SAMPLE
    creates a SAMPLE percent sample population for Melbourne 
    based on the 2016 census and with VISTA-like activities and trips.\n\n"
    exit
fi

DIR=$(dirname "$0")
SAMPLE=$1
FILENAME=mel2016_${SAMPLE}
read -r -d '' SCRIPT << EOM
source("make2016Population.R");
make2016MATSimMelbournePopulation($SAMPLE, "$DIR/$FILENAME", "$FILENAME")
EOM

CMD="Rscript --vanilla -e '$SCRIPT'"
echo $CMD && eval $CMD
