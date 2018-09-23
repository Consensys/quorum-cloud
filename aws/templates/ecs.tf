locals {
  service_name_fmt = "node-%0${min(length(format("%d", var.number_of_nodes)), length(format("%s", var.number_of_nodes))) + 1}d-%s"
  ecs_cluster_name = "quorum-network-${var.network_name}"
  quorum_bucket    = "${var.region}-ecs-${lower(var.network_name)}-${random_id.bucket_postfix.hex}"
}

resource "aws_ecs_cluster" "quorum" {
  name = "${local.ecs_cluster_name}"
}

resource "aws_ecs_task_definition" "quorum" {
  family                   = "quorum-${var.consensus_mechanism}-${var.tx_privacy_engine}-${var.network_name}"
  container_definitions    = "${replace(element(compact(local.container_definitions), 0), "/\"(true|false|[0-9]+)\"/", "$1")}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "4096"
  memory                   = "8192"
  network_mode             = "awsvpc"
  task_role_arn            = "${aws_iam_role.ecs_task.arn}"
  execution_role_arn       = "${aws_iam_role.ecs_task.arn}"

  volume {
    name = "${local.shared_volume_name}"
  }
}

resource "aws_ecs_service" "quorum" {
  count           = "${var.number_of_nodes}"
  name            = "${format(local.service_name_fmt, count.index + 1, var.network_name)}"
  cluster         = "${aws_ecs_cluster.quorum.id}"
  task_definition = "${aws_ecs_task_definition.quorum.arn}"
  launch_type     = "FARGATE"
  desired_count   = "1"

  network_configuration {
    subnets          = ["${var.subnet_ids}"]
    assign_public_ip = "${var.is_igw_subnets}"
    security_groups  = ["${aws_security_group.quorum.id}"]
  }
}

data "aws_caller_identity" "this" {}

data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid = "AllowAccess"

    actions = [
      "kms:*",
    ]

    effect = "Allow"

    resources = ["*"]

    principals {
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root",
      ]

      type = "AWS"
    }
  }
}

resource "aws_kms_key" "bucket" {
  description             = "Used to encrypt/decrypt objects stored inside bucket created for this deployment"
  policy                  = "${data.aws_iam_policy_document.kms_policy.json}"
  deletion_window_in_days = "7"
  tags                    = "${local.common_tags}"
}

resource "random_id" "bucket_postfix" {
  byte_length = 8
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "AllowAccess"
    actions = ["s3:*"]
    effect  = "Allow"

    resources = [
      "arn:aws:s3:::${local.quorum_bucket}",
      "arn:aws:s3:::${local.quorum_bucket}/*",
    ]

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
      type        = "AWS"
    }
  }

  statement {
    sid     = "DenyAccess1"
    actions = ["s3:PutObject"]
    effect  = "Deny"

    resources = [
      "arn:aws:s3:::${local.quorum_bucket}",
      "arn:aws:s3:::${local.quorum_bucket}/*",
    ]

    principals {
      identifiers = ["*"]
      type        = "AWS"
    }

    condition {
      test     = "Null"
      values   = ["true"]
      variable = "s3:x-amz-server-side-encryption"
    }
  }

  statement {
    sid     = "DenyAccess2"
    actions = ["s3:PutObject"]
    effect  = "Deny"

    resources = [
      "arn:aws:s3:::${local.quorum_bucket}",
      "arn:aws:s3:::${local.quorum_bucket}/*",
    ]

    principals {
      identifiers = ["*"]
      type        = "AWS"
    }

    condition {
      test     = "StringNotEquals"
      values   = ["aws:kms"]
      variable = "s3:x-amz-server-side-encryption"
    }
  }
}

resource "aws_s3_bucket" "quorum" {
  bucket        = "${local.quorum_bucket}"
  region        = "${var.region}"
  policy        = "${data.aws_iam_policy_document.bucket_policy.json}"
  force_destroy = true

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    "rule" {
      "apply_server_side_encryption_by_default" {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = "${aws_kms_key.bucket.arn}"
      }
    }
  }
}
