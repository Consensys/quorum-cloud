locals {
  shared_volume_name            = "quorum_shared_volume"
  shared_volume_container_path  = "/qdata"
  tx_privacy_engine_socket_file = "${local.shared_volume_container_path}/tm.ipc"

  container_definitions = [
    "${var.tx_privacy_engine == "constellation" ? jsonencode(local.constellation_container_definitions) : ""}",
  ]
}
