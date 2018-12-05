#!/bin/bash
set +e

# this utility is to clean up AWS resources that are left over due to unforeseen failure during provisioning
# required: https://github.com/rebuy-de/aws-nuke

region=$1
network_name=$2

if [[ "${region}" == "" ]] || [[ "${network_name}" == "" ]]; then
    echo "Usage: cleanup.sh <region> <network_name>"
    exit 1
fi
tmp_file="/tmp/nuke-config.yml"

cat nuke-config.tpl.yml | sed "s/_NETWORK_NAME_/${network_name}/g" | sed "s/_REGION_/${region}/g" > ${tmp_file}

aws-nuke -c ${tmp_file} --profile ${AWS_PROFILE} --no-dry-run