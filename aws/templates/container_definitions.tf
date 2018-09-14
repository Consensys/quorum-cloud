locals {
  shared_volume_name            = "quorum_shared_volume"
  shared_volume_container_path  = "/qdata"
  tx_privacy_engine_socket_file = "${local.shared_volume_container_path}/tm.ipc"

  node_key_bootstrap_container_name    = "node-key-bootstrap"
  metadata_bootstrap_container_name    = "metadata-bootstrap"
  quorum_run_container_name            = "quorum-run"
  tx_privacy_engine_run_container_name = "${var.tx_privacy_engine}-run"

  consensus_config = {
    raft = {
      geth_args = [
        "--raft",
        "--raftport ${local.raft_port}",
      ]

      enode_params = [
        "raftport=${local.raft_port}",
      ]
    }

    istanbul = {
      geth_args = [
        "--istanbul.blockperiod 1",
        "--emitcheckpoints",
      ]

      enode_params = []
    }
  }

  common_container_definitions = [
    "${local.node_key_bootstrap_container_definition}",
    "${local.metadata_bootstrap_container_definition}",
    "${local.quorum_run_container_definition}",
  ]

  container_definitions_for_constellation = [
    "${local.common_container_definitions}",
    "${local.constellation_run_container_definition}",
  ]

  container_definitions = [
    "${var.tx_privacy_engine == "constellation" ? jsonencode(local.container_definitions_for_constellation) : ""}",
  ]
}
