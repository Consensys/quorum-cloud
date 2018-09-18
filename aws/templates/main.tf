terraform {
  backend "s3" {
    # backend configuration is auto discovered by running Terraform inside _terraform_init folder
  }
}

provider "aws" {
  region  = "${var.region}"
  version = "~> 1.36"
}

provider "null" {
  version = "~> 1.0"
}

provider "random" {
  version = "~> 2.0"
}

provider "local" {
  version = "~> 1.1"
}

provider "tls" {
  version = "~> 1.2"
}

locals {
  tessera_docker_image           = "${var.tx_privacy_engine == "tessera" ? format("%s:%s", var.tessera_docker_image, var.tessera_docker_image_tag) : ""}"
  constellation_docker_image     = "${var.tx_privacy_engine == "constellation" ? format("%s:%s", var.constellation_docker_image, var.constellation_docker_image_tag) : ""}"
  quorum_docker_image            = "${format("%s:%s", var.quorum_docker_image, var.quorum_docker_image_tag)}"
  tx_privacy_engine_docker_image = "${coalesce(local.tessera_docker_image, local.constellation_docker_image)}"
  aws_cli_docker_image           = "${format("%s:%s", var.aws_cli_docker_image, var.aws_cli_docker_image_tag)}"

  common_tags = {
    "NetworkName"               = "${var.network_name}"
    "ECSClusterName"            = "${local.ecs_cluster_name}"
    "DockerImage.Quorum"        = "${local.quorum_docker_image}"
    "DockerImage.PrivacyEngine" = "${local.tx_privacy_engine_docker_image}"
  }
}
