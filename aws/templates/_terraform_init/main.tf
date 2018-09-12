provider "aws" {
  region = "${var.region}"
}

locals {
  tfinit_filename = "terraform.auto.backend_config"
  tfvars_filename = "terraform.auto.tfvars"
  deployment_id   = "${coalesce(var.deployment_id, join("", random_id.deployment_id.*.b64_url))}"
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

resource "random_id" "deployment_id" {
  count       = "${var.deployment_id == "" ? 1 : 0}"
  prefix      = "q-"
  byte_length = 8
}

resource "local_file" "tfinit" {
  filename = "${format("%s/../%s", path.module, local.tfinit_filename)}"

  content = <<EOF
# This file is auto generated. Please do not edit
# This is the backend configuration for `terraform init` in the main deployment
region="${var.region}"
bucket="${data.aws_cloudformation_export.state_bucket_name.value}"
encrypt="true"
kms_key_id="${data.aws_kms_alias.state_bucket.target_key_arn}"
key="${local.deployment_id}"
EOF
}

resource "local_file" "tfvars" {
  filename = "${format("%s/../%s", path.module, local.tfvars_filename)}"

  content = <<EOF
# This file is auto generated. Please do not edit
# This file contains the default values for required variables
region="${var.region}"
deployment_id="${local.deployment_id}"
EOF
}