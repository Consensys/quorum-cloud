resource "aws_ecs_cluster" "quorum" {
  name = "quorum-network-${var.deployment_id}"
}

resource "aws_ecs_task_definition" "quorum" {
  family                   = "quorum-${var.tx_privacy_engine}-${var.deployment_id}"
  container_definitions    = "${replace(element(compact(local.container_definitions), 0), "/\"(true|false|[0-9]+)\"/", "$1")}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "4096"
  memory                   = "8192"
  network_mode             = "awsvpc"
  execution_role_arn       = "${aws_iam_role.ecs_task.arn}"

  volume {
    name = "${local.shared_volume_name}"
  }
}

resource "aws_ecs_service" "quorum" {
  count           = "${var.number_of_nodes}"
  name            = "quorum-service-${var.deployment_id}-${count.index}"
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
