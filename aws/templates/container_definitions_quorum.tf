locals {
  quorum_rpc_port           = 22000
  quorum_p2p_port           = 21000
  quorum_data_dir           = "${local.shared_volume_container_path}/dd"
  quorum_password_file      = "${local.shared_volume_container_path}/passwords.txt"
  quorum_static_nodes       = "${local.quorum_data_dir}/static-nodes.json"
  quorum_permissioned_nodes = "${local.quorum_data_dir}/permissioned-nodes.json"
  genenis_file              = "${local.shared_volume_container_path}/genesis.json"
  node_id_file              = "${local.shared_volume_container_path}/node_id"
  node_ids_folder           = "${local.shared_volume_container_path}/nodeids"

  geth_bootstrap_commands = [
    "mkdir -p ${local.quorum_data_dir}/keystore",
    "mkdir -p ${local.quorum_data_dir}/geth",
    "mkdir -p ${local.node_ids_folder}",
    "echo \"\" > ${local.quorum_password_file}",
    "bootnode -genkey ${local.quorum_data_dir}/geth/nodekey",
    "export TASK_REVISION=$(cat ${local.task_revision_file})",
    "export HOST_IP=$(cat ${local.host_ip_file})",
    "export NODE_ID=$(bootnode -nodekey ${local.quorum_data_dir}/geth/nodekey -writeaddress)",
    "echo $NODE_ID > ${local.node_id_file}",
    "aws s3 cp ${local.node_id_file} s3://${local.s3_revision_folder}/nodeids/${local.normalized_host_ip} --sse aws:kms --sse-kms-key-id ${var.quorum_bucket_kms_key_arn}",
    "count=0; while [ $count -lt ${var.number_of_nodes} ]; do aws s3 cp --recursive s3://${local.s3_revision_folder}/nodeids ${local.node_ids_folder}; count=$(ls ${local.node_ids_folder} | grep ^ip | wc -l); echo \"Wait for other nodes to report their IDs ... $count/${var.number_of_nodes}\"; sleep 3; done",
    "echo \"All nodes have registered their IDs\"",
    "echo \"Creating ${local.quorum_static_nodes} and ${local.quorum_permissioned_nodes}\"",
    "all=\"\"; for f in `ls ${local.node_ids_folder}`; do nodeid=$(cat ${local.node_ids_folder}/$f); ip=$(cat ${local.hosts_folder}/$f); all=\"$all,\\\"enode://$nodeid@$ip:${local.quorum_p2p_port}?discport=0${data.null_data_source.concensus_mechanism_enode_args.inputs[var.concensus_mechanism]}\\\"\"; done; all=$${all:1}",
    "echo \"[$all]\" > ${local.quorum_static_nodes}",
    "echo \"[$all]\" > ${local.quorum_permissioned_nodes}",
    "echo '${replace(jsonencode(local.genesis), "/\"(true|false|[0-9]+)\"/" , "$1")}' > ${local.genenis_file}",
    "geth --datadir ${local.quorum_data_dir} init ${local.genenis_file}",
  ]

  raft_port = 50400

  additional_args = "${split(data.null_data_source.concensus_mechanism_geth_args.inputs[var.concensus_mechanism], ",")}"

  geth_args = [
    "--datadir ${local.quorum_data_dir}",
    "--permissioned",
    "--rpc",
    "--rpcaddr 0.0.0.0",
    "--rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,${var.concensus_mechanism}",
    "--rpcport ${local.quorum_rpc_port}",
    "--port ${local.quorum_p2p_port}",
    "--unlock 0",
    "--password ${local.quorum_password_file}",
    "--nodiscover",
    "--networkid ${random_integer.network_id.result}",
    "--verbosity 4",
  ]

  quorum_bootstrap_container_definition = {
    name      = "geth-bootstrap"
    image     = "${local.quorum_docker_image}"
    essential = "false"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region        = "${var.region}"
        awslogs-stream-prefix = "${var.deployment_id}"
      }
    }

    mountPoints = [
      {
        sourceVolume  = "${local.shared_volume_name}"
        containerPath = "${local.shared_volume_container_path}"
      },
    ]

    healthCheck = {
      interval = 5
      retries  = 10

      command = [
        "CMD-SHELL",
        "[ -S ${local.shared_volume_container_path}/tm.pub ];",
      ]
    }

    volumesFrom = [
      {
        sourceContainer = "config-bootstrap"
      },
    ]

    entrypoint = [
      "/bin/sh",
      "-c",
      "${join("\n", local.geth_bootstrap_commands)}",
    ]

    dockerLabels = "${local.common_tags}"
  }

  quorum_container_definition = {
    name      = "geth-run"
    image     = "${local.quorum_docker_image}"
    essential = "true"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region        = "${var.region}"
        awslogs-stream-prefix = "${var.deployment_id}"
      }
    }

    mountPoints = [
      {
        sourceVolume  = "${local.shared_volume_name}"
        containerPath = "${local.shared_volume_container_path}"
      },
    ]

    healthCheck = {
      interval = 5
      retries  = 10

      command = [
        "CMD-SHELL",
        "[ -S ${local.shared_volume_container_path}/tm.pub ];",
      ]
    }

    volumesFrom = [
      {
        sourceContainer = "${var.tx_privacy_engine}-bootstrap"
      },
      {
        sourceContainer = "config-bootstrap"
      },
      {
        sourceContainer = "${var.tx_privacy_engine}-run"
      },
      {
        sourceContainer = "geth-bootstrap"
      },
    ]

    environment = [
      {
        name  = "PRIVATE_CONFIG"
        value = "${local.tx_privacy_engine_socket_file}"
      },
    ]

    command = "${concat(local.geth_args, local.additional_args)}"

    dockerLabels = "${local.common_tags}"
  }

  genesis = {
    "alloc" = {
      "0xed9d02e382b34818e88b88a309c7fe71e65f419d" = {
        "balance" = "1000000000000000000000000000"
      }

      "0xca843569e3427144cead5e4d5999a3d0ccf92b8e" = {
        "balance" = "1000000000000000000000000000"
      }

      "0x0fbdc686b912d7722dc86510934589e0aaf3b55a" = {
        "balance" = "1000000000000000000000000000"
      }

      "0x9186eb3d20cbd1f5f992a950d808c4495153abd5" = {
        "balance" = "1000000000000000000000000000"
      }

      "0x0638e1574728b6d862dd5d3a3e0942c3be47d996" = {
        "balance" = "1000000000000000000000000000"
      }
    }

    "coinbase" = "0x0000000000000000000000000000000000000000"

    "config" = {
      "byzantiumBlock" = 1
      "chainId"        = 10
      "eip150Block"    = 1
      "eip155Block"    = 0
      "eip150Hash"     = "0x0000000000000000000000000000000000000000000000000000000000000000"
      "eip158Block"    = 1
      "isQuorum"       = "true"
    }

    "difficulty" = "0x0"
    "extraData"  = "0x0000000000000000000000000000000000000000000000000000000000000000"
    "gasLimit"   = "0xE0000000"
    "mixhash"    = "0x00000000000000000000000000000000000000647572616c65787365646c6578"
    "nonce"      = "0x0"
    "parentHash" = "0x0000000000000000000000000000000000000000000000000000000000000000"
    "timestamp"  = "0x00"
  }
}

resource "random_integer" "network_id" {
  min = 2018
  max = 9999

  keepers = {
    changes_when = "${var.deployment_id}"
  }
}

data "null_data_source" "concensus_mechanism_geth_args" {
  inputs {
    raft     = "--raft,--raftport ${local.raft_port}"
    istanbul = "--istanbul.blockperiod 1,--emitcheckpoints"
  }
}

data "null_data_source" "concensus_mechanism_enode_args" {
  inputs {
    raft     = "&raftport=${local.raft_port}"
    istanbul = ""
  }
}
