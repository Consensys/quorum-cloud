terraform {
  backend "s3" {
    # backend configuration is auto discovered by running Terraform inside _terraform_init folder
  }
}

provider "aws" {
  region  = "${var.region}"
  version = "~> 1.35"
}

provider "null" {
  version = "~> 1.0"
}

provider "tls" {
  version = "~> 1.2"
}

locals {
  tessera_docker_image           = "${var.tx_privacy_engine == "tessera" ? format("%s:%s", var.tessera_docker_image, var.tessera_docker_image_tag) : ""}"
  constellation_docker_image     = "${var.tx_privacy_engine == "constellation" ? format("%s:%s", var.constellation_docker_image, var.constellation_docker_image_tag) : ""}"
  quorum_docker_image            = "${format("%s:%s", var.quorum_docker_image, var.quorum_docker_image_tag)}"
  tx_privacy_engine_docker_image = "${coalesce(local.tessera_docker_image, local.constellation_docker_image)}"

  common_tags = {
    "DeploymentId"              = "${var.deployment_id}"
    "DockerImage.Quorum"        = "${local.quorum_docker_image}"
    "DockerImage.PrivacyEngine" = "${local.tx_privacy_engine_docker_image}"
  }
}

resource "tls_private_key" "keys" {
  count       = "${var.number_of_nodes}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}
