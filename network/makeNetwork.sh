#!/usr/bin/env bash
declare -a FLAGS

FLAGS=(F 0.01 F F F F F)

while test $# -gt 0
do
    case "$1" in
        -t) FLAGS[0]=T
            ;;
        -s) FLAGS[1]=20
            ;;
        -z) FLAGS[2]=T
            ;;
        -pt) FLAGS[3]=T
            ;;
        -ivbm) FLAGS[4]=T
            ;;                
        -xml) FLAGS[5]=T
            ;;
        -sqlite) FLAGS[6]=T
            ;;
        -A) FLAGS=(F 20 T T F T T)
            ;;
        --*) echo "bad option $1"
            ;;
        *) echo "Unkown option $1"
            ;;
    esac
    shift
done
ALLFLAGS=$(echo ${FLAGS[*]} | sed -e 's/ /,/g')

read -r -d '' SCRIPT << EOM
source("MATSimNetworkGenerator.R");
makeMatsimNetwork($ALLFLAGS)
EOM

CMD="Rscript --vanilla --verbose -e '$SCRIPT'"
echo $CMD && eval $CMD
