locals {
  quorum_container_definition = {
    name      = "geth"
    image     = "${local.quorum_docker_image}"
    essential = "true"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region        = "${var.region}"
        awslogs-stream-prefix = "${var.deployment_id}"
      }
    }

    mountPoints = [
      {
        sourceVolume  = "${local.shared_volume_name}"
        containerPath = "${local.shared_volume_container_path}"
      },
    ]

    healthCheck = {
      interval = 5
      retries  = 10

      command = [
        "CMD-SHELL",
        "[ -S ${local.shared_volume_container_path}/tm.pub ];",
      ]
    }

    command = [
      "--generatekeys=${local.shared_volume_container_path}/tm",
    ]

    dockerLabels = "${local.common_tags}"
  }
}
