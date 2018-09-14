locals {
  quorum_rpc_port                = 22000
  quorum_p2p_port                = 21000
  raft_port                      = 50400
  quorum_data_dir                = "${local.shared_volume_container_path}/dd"
  quorum_password_file           = "${local.shared_volume_container_path}/passwords.txt"
  quorum_static_nodes_file       = "${local.quorum_data_dir}/static-nodes.json"
  quorum_permissioned_nodes_file = "${local.quorum_data_dir}/permissioned-nodes.json"
  genenis_file                   = "${local.shared_volume_container_path}/genesis.json"
  node_id_file                   = "${local.shared_volume_container_path}/node_id"
  node_ids_folder                = "${local.shared_volume_container_path}/nodeids"
  accounts_folder                = "${local.shared_volume_container_path}/accounts"

  consensus_config_map = "${local.consensus_config[var.consensus_mechanism]}"

  quorum_config_commands = [
    "mkdir -p ${local.quorum_data_dir}/geth",
    "echo \"\" > ${local.quorum_password_file}",
    "echo \"Creating ${local.quorum_static_nodes_file} and ${local.quorum_permissioned_nodes_file}\"",
    "all=\"\"; for f in `ls ${local.node_ids_folder}`; do nodeid=$(cat ${local.node_ids_folder}/$f); ip=$(cat ${local.hosts_folder}/$f); all=\"$all,\\\"enode://$nodeid@$ip:${local.quorum_p2p_port}?discport=0&${join("&", local.consensus_config_map["enode_params"])}\\\"\"; done; all=$${all:1}",
    "echo \"[$all]\" > ${local.quorum_static_nodes_file}",
    "echo \"[$all]\" > ${local.quorum_permissioned_nodes_file}",
    "echo Permissioned Nodes: $(cat ${local.quorum_permissioned_nodes_file})",
    "geth --datadir ${local.quorum_data_dir} init ${local.genenis_file}",
  ]

  additional_args = "${local.consensus_config_map["geth_args"]}"

  geth_args = [
    "--datadir ${local.quorum_data_dir}",
    "--permissioned",
    "--rpc",
    "--rpcaddr 0.0.0.0",
    "--rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,${var.consensus_mechanism}",
    "--rpcport ${local.quorum_rpc_port}",
    "--port ${local.quorum_p2p_port}",
    "--unlock 0",
    "--password ${local.quorum_password_file}",
    "--nodiscover",
    "--networkid ${random_integer.network_id.result}",
    "--verbosity 4",
  ]

  quorum_run_commands = [
    "set -e",
    "echo Wait until metadata bootstrap completed ...",
    "while [ ! -f \"${local.metadata_bootstrap_container_status_file}\" ]; do sleep 1; done",
    "echo Wait until ${var.tx_privacy_engine} is ready ...",
    "while [ ! -S \"${local.tx_privacy_engine_socket_file}\" ]; do sleep 1; done",
    "${local.quorum_config_commands}",
    "geth ${join(" ", concat(local.geth_args, local.additional_args))}",
  ]

  quorum_run_container_definition = {
    name      = "${local.quorum_run_container_name}"
    image     = "${local.quorum_docker_image}"
    essential = "true"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region        = "${var.region}"
        awslogs-stream-prefix = "${var.network_name}"
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
        "[ -S ${local.quorum_data_dir}/geth.ipc ];",
      ]
    }

    volumesFrom = [
      {
        sourceContainer = "${local.metadata_bootstrap_container_name}"
      },
      {
        sourceContainer = "${local.tx_privacy_engine_run_container_name}"
      },
    ]

    environment = [
      {
        name  = "PRIVATE_CONFIG"
        value = "${local.tx_privacy_engine_socket_file}"
      },
    ]

    entrypoint = [
      "/bin/sh",
      "-c",
      "${join("\n", local.quorum_run_commands)}",
    ]

    dockerLabels = "${local.common_tags}"
  }

  genesis = {
    "alloc" = {}

    "coinbase" = "0x0000000000000000000000000000000000000000"

    "config" = {
      "byzantiumBlock" = 1
      "chainId"        = "${random_integer.network_id.result}"
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
    changes_when = "${var.network_name}"
  }
}
