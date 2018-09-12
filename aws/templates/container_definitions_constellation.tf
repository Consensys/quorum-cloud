locals {
  constellation_socket_file = "${local.shared_volume_container_path}/tm.ipc"
  constellation_port        = 10000

  constellation_container_definitions = [
    {
      name      = "${var.tx_privacy_engine}-bootstrap"
      image     = "${local.tx_privacy_engine_docker_image}"
      essential = "false"

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
    },
    {
      name      = "${var.tx_privacy_engine}-run"
      image     = "${local.tx_privacy_engine_docker_image}"
      essential = "true"

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
          awslogs-region        = "${var.region}"
          awslogs-stream-prefix = "${var.deployment_id}"
        }
      }

      portMappings = [
        {
          containerPort = "${local.constellation_port}"
        },
      ]

      mountPoints = [
        {
          sourceVolume  = "${local.shared_volume_name}"
          containerPath = "${local.shared_volume_container_path}"
        },
      ]

      volumesFrom = [
        {
          sourceContainer = "${var.tx_privacy_engine}-bootstrap"
        },
      ]

      healthCheck = {
        interval = 5
        retries  = 10

        command = [
          "CMD-SHELL",
          "[ -S ${local.constellation_socket_file} ];",
        ]
      }

      command = [
        "--url=http://$(hostname -i):${local.constellation_port}/",
        "--port=${local.constellation_port}",
        "--socket=${local.constellation_socket_file}",
        "--othernodes=http://localhost:${local.constellation_port}/",
        "--publickeys=${local.shared_volume_container_path}/tm.pub",
        "--privatekeys=${local.shared_volume_container_path}/tm.key",
        "--storage=/constellation",
        "--verbosity=4",
      ]

      dockerLabels = "${local.common_tags}"
    },
  ]
}
