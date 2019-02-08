#!/bin/bash
killall geth bootnode constellation-node

if [ "`jps | grep tessera`" != "" ]
then
  jps | grep tessera | cut -d " " -f1 | xargs kill
else
  echo "tessera: no process found"
fi

UP=true
k=20
while ${UP}; do
    UP=true
        set +e
        result=$(netstat -n|grep TIME | wc -l)
        set -e
        if [ ${result} == 0 ]; then
            echo "geth, bootnode, tessera & constellation all processes are stopped."
            UP=false
	else
		sleep 5
        fi

    k=$((k - 1))
    if [ ${k} -le 0 ]; then
        echo "quorum processes taking a long time to stop.  Look at the logs in qdata/logs/ for help diagnosing the problem."
        exit
    fi
    echo "Waiting until all quorum processes are stopping...${result}"

done
