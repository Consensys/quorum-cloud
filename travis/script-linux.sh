#!/bin/bash

# This script is called from TRAVIS CI configured in quorum repo. Its called from the script: part of the build job
# This script brings up the 4node network for a specific consensus

consensus=${TF_VAR_consensus_mechanism}

echo "script started for consensus: $consensus ..."
set -e
echo "start quorum network for consensus $consensus ..."
cd $TRAVIS_HOME/quorum-cloud/travis/4nodes
./init.sh $consensus
set -e
./start.sh $consensus tessera
echo "script done"
