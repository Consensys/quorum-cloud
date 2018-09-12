locals {
  shared_volume_name           = "quorum_shared_volume"
  shared_volume_container_path = "/qdata"

  container_definitions = [
    "${var.tx_privacy_engine == "constellation" ? jsonencode(local.constellation_container_definitions) : ""}",
  ]
}