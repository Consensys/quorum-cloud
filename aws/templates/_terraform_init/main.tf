provider "aws" {
  region = "${var.region}"
}

locals {
  filename = "terraform.auto.backend_config"
}

data "aws_cloudformation_export" "state_bucket_name" {
  name = "quorum-deployment-state-bucket-name"
}

data "aws_cloudformation_export" "kms_key_alias" {
  name = "quorum-deployment-state-bucket-kms-key-alias"
}

data "aws_kms_alias" "state_bucket" {
  name = "${data.aws_cloudformation_export.kms_key_alias.value}"
}

resource "local_file" "tfinit" {
  filename = "${format("%s/../%s", path.module, local.filename)}"

  content = <<VARS
# This file is auto generated. Please do not edit
# This is the backend configuration for `terraform init` in the main deployment
region="${var.region}"
bucket="${data.aws_cloudformation_export.state_bucket_name.value}"
encrypt="true"
kms_key_id="${data.aws_kms_alias.state_bucket.target_key_arn}"
key="${var.deployment_id}"
VARS
}
