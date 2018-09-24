locals {
  host_ip_file         = "${local.shared_volume_container_path}/host_ip"
  task_revision_file   = "${local.shared_volume_container_path}/task_revision"
  service_file         = "${local.shared_volume_container_path}/service"
  account_address_file = "${local.shared_volume_container_path}/first_account_address"
  hosts_folder         = "${local.shared_volume_container_path}/hosts"

  metadata_bootstrap_container_status_file = "${local.shared_volume_container_path}/metadata_bootstrap_container_status"

  // For S3 related operations
  s3_revision_folder = "${local.quorum_bucket}/rev_$TASK_REVISION"
  normalized_host_ip = "ip_$(echo $HOST_IP | sed -e 's/\\./_/g')"

  node_key_bootstrap_commands = [
    "mkdir -p ${local.quorum_data_dir}/geth",
    "echo \"\" > ${local.quorum_password_file}",
    "bootnode -genkey ${local.quorum_data_dir}/geth/nodekey",
    "export NODE_ID=$(bootnode -nodekey ${local.quorum_data_dir}/geth/nodekey -writeaddress)",
    "echo Creating an account for this node",
    "geth --datadir ${local.quorum_data_dir} account new --password ${local.quorum_password_file}",
    "export KEYSTORE_FILE=$(ls ${local.quorum_data_dir}/keystore/ | head -n1)",
    "export ACCOUNT_ADDRESS=$(cat ${local.quorum_data_dir}/keystore/$KEYSTORE_FILE | sed 's/^.*\"address\":\"\\([^\"]*\\)\".*$/\\1/g')",
    "echo Writing account address $ACCOUNT_ADDRESS to ${local.account_address_file}",
    "echo $ACCOUNT_ADDRESS > ${local.account_address_file}",
    "echo Writing Node Id [$NODE_ID] to ${local.node_id_file}",
    "echo $NODE_ID > ${local.node_id_file}",
  ]

  node_key_bootstrap_container_definition = {
    name      = "${local.node_key_bootstrap_container_name}"
    image     = "${local.quorum_docker_image}"
    essential = "false"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region        = "${var.region}"
        awslogs-stream-prefix = "logs"
      }
    }

    mountPoints = [
      {
        sourceVolume  = "${local.shared_volume_name}"
        containerPath = "${local.shared_volume_container_path}"
      },
    ]

    environments = []

    portMappings = []

    volumesFrom = []

    healthCheck = {
      interval    = 30
      retries     = 10
      timeout     = 60
      startPeriod = 300

      command = [
        "CMD-SHELL",
        "[ -f ${local.node_id_file} ];",
      ]
    }

    entrypoint = [
      "/bin/sh",
      "-c",
      "${join("\n", local.node_key_bootstrap_commands)}",
    ]

    dockerLabels = "${local.common_tags}"

    cpu = 0
  }

  // this is very BADDDDDD but for now i don't have any other better option
  validator_address_program = <<EOP
package main

import (
	"encoding/hex"
	"fmt"
	"os"

	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/p2p/discover"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("missing enode value")
		os.Exit(1)
	}
	enode := os.Args[1]
	nodeId, err := discover.HexID(enode)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	pub, err := nodeId.Pubkey()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	fmt.Printf("0x%s\n", hex.EncodeToString(crypto.PubkeyToAddress(*pub).Bytes()))
}
EOP

  // bootstrap the extraData, this must be used inside metadata_bootstrap_commands to inherit metadata info
  istanbul_bootstrap_commands = [
    "apk add --repository http://dl-cdn.alpinelinux.org/alpine/v3.7/community go=1.9.4-r0",
    "apk add git gcc musl-dev linux-headers",
    "git clone ${element(local.consensus_config_map["git_url"], 0)} /istanbul-tools/src/github.com/getamis/istanbul-tools",
    "export GOPATH=/istanbul-tools",
    "export GOROOT=/usr/lib/go",
    "echo '${local.validator_address_program}' > /istanbul-tools/src/github.com/getamis/istanbul-tools/extra.go",
    "all=\"\"; for f in `ls ${local.node_ids_folder}`; do address=$(cat ${local.node_ids_folder}/$f); all=\"$all,$(go run /istanbul-tools/src/github.com/getamis/istanbul-tools/extra.go $address)\"; done",
    "all=\"$${all:1}\"",
    "echo Validator Addresses: $all",
    "extraData=\"\\\"$(go run /istanbul-tools/src/github.com/getamis/istanbul-tools/cmd/istanbul/main.go extra encode --validators $all | awk -F: '{print $2}' | tr -d ' ')\\\"\"",
  ]

  metadata_bootstrap_commands = [
    "set -e",
    "echo Wait until Node Key is ready ...",
    "while [ ! -f \"${local.node_id_file}\" ]; do sleep 1; done",
    "apk update",
    "apk add curl jq",
    "export TASK_REVISION=$(curl -s 169.254.170.2/v2/metadata | jq '.Revision' -r)",
    "echo \"Task Revision: $TASK_REVISION\"",
    "echo $TASK_REVISION > ${local.task_revision_file}",
    "export HOST_IP=$(curl -s 169.254.170.2/v2/metadata | jq '.Containers[] | select(.Name == \"${local.metadata_bootstrap_container_name}\") | .Networks[] | select(.NetworkMode == \"awsvpc\") | .IPv4Addresses[0]' -r )",
    "echo \"Host IP: $HOST_IP\"",
    "echo $HOST_IP > ${local.host_ip_file}",
    "export TASK_ARN=$(curl -s 169.254.170.2/v2/metadata | jq -r '.TaskARN')",
    "aws ecs describe-tasks --cluster ${local.ecs_cluster_name} --tasks $TASK_ARN | jq -r '.tasks[0] | .group' > ${local.service_file}",
    "mkdir -p ${local.hosts_folder}",
    "mkdir -p ${local.node_ids_folder}",
    "mkdir -p ${local.accounts_folder}",
    "aws s3 cp ${local.node_id_file} s3://${local.s3_revision_folder}/nodeids/${local.normalized_host_ip} --sse aws:kms --sse-kms-key-id ${aws_kms_key.bucket.arn}",
    "aws s3 cp ${local.host_ip_file} s3://${local.s3_revision_folder}/hosts/${local.normalized_host_ip} --sse aws:kms --sse-kms-key-id ${aws_kms_key.bucket.arn}",
    "aws s3 cp ${local.account_address_file} s3://${local.s3_revision_folder}/accounts/${local.normalized_host_ip} --sse aws:kms --sse-kms-key-id ${aws_kms_key.bucket.arn}",

    // Gather all IPs
    "count=0; while [ $count -lt ${var.number_of_nodes} ]; do count=$(ls ${local.hosts_folder} | grep ^ip | wc -l); aws s3 cp --recursive s3://${local.s3_revision_folder}/hosts ${local.hosts_folder} > /dev/null 2>&1 | echo \"Wait for other containers to report their IPs ... $count/${var.number_of_nodes}\"; sleep 1; done",

    "echo \"All containers have reported their IPs\"",

    // Gather all Accounts
    "count=0; while [ $count -lt ${var.number_of_nodes} ]; do count=$(ls ${local.accounts_folder} | grep ^ip | wc -l); aws s3 cp --recursive s3://${local.s3_revision_folder}/accounts ${local.accounts_folder} > /dev/null 2>&1 | echo \"Wait for other nodes to report their accounts ... $count/${var.number_of_nodes}\"; sleep 1; done",

    "echo \"All nodes have registered accounts\"",

    // Gather all Node IDs
    "count=0; while [ $count -lt ${var.number_of_nodes} ]; do count=$(ls ${local.node_ids_folder} | grep ^ip | wc -l); aws s3 cp --recursive s3://${local.s3_revision_folder}/nodeids ${local.node_ids_folder} > /dev/null 2>&1 | echo \"Wait for other nodes to report their IDs ... $count/${var.number_of_nodes}\"; sleep 1; done",

    "echo \"All nodes have registered their IDs\"",

    // Prepare Genesis file
    "alloc=\"\"; for f in `ls ${local.accounts_folder}`; do address=$(cat ${local.accounts_folder}/$f); alloc=\"$alloc,\\\"$address\\\": { \"balance\": \"\\\"1000000000000000000000000000\\\"\"}\"; done",

    "alloc=\"{$${alloc:1}}\"",
    "extraData=\"\\\"0x0000000000000000000000000000000000000000000000000000000000000000\\\"\"",
    "${var.consensus_mechanism == "istanbul" ? join("\n", local.istanbul_bootstrap_commands) : ""}",
    "mixHash=\"\\\"${element(local.consensus_config_map["genesis_mixHash"], 0)}\\\"\"",
    "difficulty=\"\\\"${element(local.consensus_config_map["genesis_difficulty"], 0)}\\\"\"",
    "echo '${replace(jsonencode(local.genesis), "/\"(true|false|[0-9]+)\"/", "$1")}' | jq \". + { alloc : $alloc, extraData: $extraData, mixHash: $mixHash, difficulty: $difficulty}${var.consensus_mechanism == "istanbul" ? " | .config=.config + {istanbul: {epoch: 30000, policy: 0} }" : ""}\" > ${local.genesis_file}",
    "cat ${local.genesis_file}",

    // Write status
    "echo \"Done!\" > ${local.metadata_bootstrap_container_status_file}",

    "echo Wait until privacy engine initialized ...",
    "while [ ! -f \"${local.tx_privacy_engine_address_file}\" ]; do sleep 1; done",
    "aws s3 cp ${local.tx_privacy_engine_address_file} s3://${local.s3_revision_folder}/privacyaddresses/${local.normalized_host_ip} --sse aws:kms --sse-kms-key-id ${aws_kms_key.bucket.arn}",
  ]

  metadata_bootstrap_container_definition = {
    name      = "${local.metadata_bootstrap_container_name}"
    image     = "${local.aws_cli_docker_image}"
    essential = "false"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region        = "${var.region}"
        awslogs-stream-prefix = "logs"
      }
    }

    mountPoints = [
      {
        sourceVolume  = "${local.shared_volume_name}"
        containerPath = "${local.shared_volume_container_path}"
      },
    ]

    environments = []

    portMappings = []

    volumesFrom = [
      {
        sourceContainer = "${local.node_key_bootstrap_container_name}"
      },
    ]

    healthCheck = {
      interval    = 30
      retries     = 10
      timeout     = 60
      startPeriod = 300

      command = [
        "CMD-SHELL",
        "[ -f ${local.metadata_bootstrap_container_status_file} ];",
      ]
    }

    entryPoint = [
      "/bin/sh",
      "-c",
      "${join("\n", local.metadata_bootstrap_commands)}",
    ]

    dockerLabels = "${local.common_tags}"

    cpu = 0
  }
}
