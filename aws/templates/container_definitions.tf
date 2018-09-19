locals {
  shared_volume_name            = "quorum_shared_volume"
  shared_volume_container_path  = "/qdata"
  tx_privacy_engine_socket_file = "${local.shared_volume_container_path}/tm.ipc"

  node_key_bootstrap_container_name           = "node-key-bootstrap"
  metadata_bootstrap_container_name           = "metadata-bootstrap"
  quorum_run_container_name                   = "quorum-run"
  tx_privacy_engine_run_container_name        = "${var.tx_privacy_engine}-run"
  istanbul_extradata_bootstrap_container_name = "istanbul-extradata-bootstrap"

  consensus_config = {
    raft = {
      geth_args = [
        "--raft",
        "--raftport ${local.raft_port}",
      ]

      enode_params = [
        "raftport=${local.raft_port}",
      ]

      genesis_mixHash = ["0x00000000000000000000000000000000000000647572616c65787365646c6578"]
      genesis_difficulty = ["0x00"]
    }

    istanbul = {
      geth_args = [
        "--istanbul.blockperiod 1",
        "--emitcheckpoints",
        "--syncmode full",
        "--mine",
        "--minerthreads 1",
      ]

      enode_params = []

      genesis_mixHash = ["0x63746963616c2062797a616e74696e65206661756c7420746f6c6572616e6365"]
      genesis_difficulty = ["0x01"]

      git_url = ["https://github.com/getamis/istanbul-tools"]
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

  container_definitions_for_tessera = [
    "${local.common_container_definitions}",
    "${local.tessera_run_container_definition}",
  ]

  container_definitions = [
    "${var.tx_privacy_engine == "constellation" ? jsonencode(local.container_definitions_for_constellation) : ""}",
    "${var.tx_privacy_engine == "tessera" ? jsonencode(local.container_definitions_for_tessera) : ""}",
  ]
}
