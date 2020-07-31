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


read -r -d '' SCRIPT << EOM
source("MATSimNetworkGenerator.R");
makeMatsimNetwork(${FLAGS[0]}, ${FLAGS[1]}, ${FLAGS[2]}, ${FLAGS[3]}, ${FLAGS[4]}, F, ${FLAGS[5]}, ${FLAGS[6]})
EOM

CMD="Rscript --vanilla --verbose -e '$SCRIPT'"
echo $CMD && eval $CMD
