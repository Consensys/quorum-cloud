locals {
  service_name_fmt = "node-%0${min(length(format("%d", var.number_of_nodes)), length(format("%s", var.number_of_nodes))) + 1}d-%s"
  ecs_cluster_name = "quorum-network-${var.network_name}"
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
  name            = "${format(local.service_name_fmt, count.index, var.network_name)}"
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

# using these resources to make sure we clean up objects created by containers
resource "aws_s3_bucket_object" "quorum" {
  bucket     = "${var.quorum_bucket}"
  kms_key_id = "${var.quorum_bucket_kms_key_arn}"

  key            = "${var.network_name}/"
  content_base64 = "Cg=="
  tags           = "${local.common_tags}"
}

/*
resource "aws_s3_bucket_object" "revision" {
  bucket     = "${var.quorum_bucket}"
  kms_key_id = "${var.quorum_bucket_kms_key_arn}"

  # this key has to be in sync with ${local.s3_revision_folder} which can't be used here due to circular dependency
  key            = "${var.network_name}/rev_${aws_ecs_task_definition.quorum.revision}/"
  content_base64 = "Cg=="
  tags           = "${local.common_tags}"
}
*/

