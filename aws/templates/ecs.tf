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
