locals {
  shared_volume = "quorum_shared_volume"
}

resource "aws_ecs_cluster" "quorum" {
  name = "quorum-network-${var.deployment_id}"
}

resource "aws_cloudwatch_log_group" "quorum" {
  name              = "quorum-log-${var.deployment_id}"
  retention_in_days = "7"
  tags              = "${local.common_tags}"
}

data "template_file" "container_definitions" {
  count = "${var.number_of_nodes}"

  template = "${file(format("%s/container_definitions.json", path.module))}"

  vars {
    region                         = "${var.region}"
    quorum_log_group               = "${aws_cloudwatch_log_group.quorum.name}"
    quorum_docker_image            = "${local.quorum_docker_image}"
    tx_privacy_engine_docker_image = "${local.tx_privacy_engine_docker_image}"

    commands = <<EOF
[
  "mkdir -p /constellation",
  "echo "socket=\"/${local.shared_volume}/tm.ipc\"\npublickeys=[\"/${local.shared_volume}/tm.pub\"]\n" > /${local.shared_volume}/tm.conf",
  "constellation-node --generatekeys=/constellation/tm",
  "cp /constellation/tm.pub /${local.shared_volume}/tm.pub"
]
EOF
    entry_point = <<EOF
[
  "constellation-node", 
  "--url=http://127.0.0.1:10000",
  "--port=10000",
  "--socket=/${local.shared_volume}/tm.ipc",
  "--othernodes=http://172.16.239.101:10001,http://172.16.239.102:10002,http://172.16.239.103:10003/",
  "--publickeys=/constellation/tm.pub",
  "--privatekeys=/constellation/tm.key",
  "--storage=/constellation",
  "--verbosity=4"
]
EOF
  }
}

resource "aws_ecs_task_definition" "quorum" {
  count                    = "${var.number_of_nodes}"
  family                   = "quorum-${var.tx_privacy_engine}-${var.deployment_id}"
  container_definitions    = "${element(data.template_file.container_definitions.*.rendered, count.index)}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "4096"
  memory                   = "8192"

  volume {
    name = "${local.shared_volume}"
  }
}

resource "aws_ecs_service" "quorum" {
  count           = "${var.number_of_nodes}"
  name            = "quorum-service-${var.deployment_id}-${count.index}"
  cluster         = "${aws_ecs_cluster.quorum.id}"
  task_definition = "${aws_ecs_task_definition.quorum.arn}"
  iam_role        = "${aws_iam_role.ecs.name}"

  desired_count = "1"

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
}
