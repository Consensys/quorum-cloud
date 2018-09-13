locals {
  constellation_socket_file = "${local.shared_volume_container_path}/tm.ipc"
  constellation_port        = 10000

  host_bootstrap_commands = [
    "apk update",
    "apk add curl jq",
    "export TASK_REVISION=$(curl -s 169.254.170.2/v2/metadata | jq '.Revision' -r)",
    "echo \"Task Revision: $TASK_REVISION\"",
    "export HOST_IP=$(curl -s 169.254.170.2/v2/metadata | jq '.Containers[] | select(.Name == \"host-bootstrap\") | .Networks[] | select(.NetworkMode == \"awsvpc\") | .IPv4Addresses[0]' -r )",
    "echo \"Host IP: $HOST_IP\"",
    "echo $HOST_IP > ${local.shared_volume_container_path}/host_ip",
    "aws sts get-caller-identity",
    "aws s3 cp ${local.shared_volume_container_path}/host_ip s3://${local.quorum_bucket}/rev_$TASK_REVISION/hosts/ip_$(echo $HOST_IP | sed -e 's/\\./_/g') --sse aws:kms --sse-kms-key-id ${var.quorum_bucket_kms_key_arn}",
    "",
  ]

  constellation_container_definitions = [
    {
      name      = "host-bootstrap"
      image     = "${local.aws_cli_docker_image}"
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
          "[ -S ${local.shared_volume_container_path}/host_ip ];",
        ]
      }

      entryPoint = [
        "/bin/sh",
        "-c",
        "${join("\n", local.host_bootstrap_commands)}",
      ]

      dockerLabels = "${local.common_tags}"
    },
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
        {
          sourceContainer = "host-bootstrap"
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
        "--url=http://$(cat ${local.shared_volume_container_path}/host_ip):${local.constellation_port}/",
        "--port=${local.constellation_port}",
        "--socket=${local.constellation_socket_file}",
        "--othernodes=http://$(cat ${local.shared_volume_container_path}/host_ip):${local.constellation_port}/",
        "--publickeys=${local.shared_volume_container_path}/tm.pub",
        "--privatekeys=${local.shared_volume_container_path}/tm.key",
        "--storage=/constellation",
        "--verbosity=4",
      ]

      dockerLabels = "${local.common_tags}"
    },
  ]
}
