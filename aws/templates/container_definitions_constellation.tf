locals {
  constellation_config_file = "${local.shared_volume_container_path}/constellation.cfg"
  constellation_port        = 10000

  constellation_config_commands = [
    "constellation-node --generatekeys=${local.shared_volume_container_path}/tm",
    "export HOST_IP=$(cat ${local.host_ip_file})",
    "echo \"\nCreating ${local.constellation_config_file}\"",
    "all=\"\"; for f in `ls ${local.hosts_folder}`; do ip=$(cat ${local.hosts_folder}/$f); all=\"$all,\\\"http://$ip:${local.constellation_port}/\\\"\"; done; all=$${all:1}",
    "echo \"\"> ${local.constellation_config_file}",
    "echo \"url = \\\"http://$HOST_IP/\\\"\" >> ${local.constellation_config_file}",
    "echo \"port = ${local.constellation_port}\" >> ${local.constellation_config_file}",
    "echo \"socket = \\\"${local.tx_privacy_engine_socket_file}\\\"\" >> ${local.constellation_config_file}",
    "echo \"othernodes = [$all]\" >> ${local.constellation_config_file}",
    "echo \"publickeys = [\\\"${local.shared_volume_container_path}/tm.pub\\\"]\" >> ${local.constellation_config_file}",
    "echo \"privatekeys = [\\\"${local.shared_volume_container_path}/tm.key\\\"]\" >> ${local.constellation_config_file}",
    "echo \"storage = \\\"/constellation\\\"\" >> ${local.constellation_config_file}",
    "echo \"verbosity = 4\" >> ${local.constellation_config_file}",
    "cat ${local.constellation_config_file}",
  ]

  constellation_config_container_definition = {
    name      = "${local.tx_privacy_engine_bootstrap_container_name}"
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

    volumesFrom = [
      {
        sourceContainer = "${local.metadata_bootstrap_container_name}"
      },
      {
        sourceContainer = "${local.node_key_bootstrap_container_name}"
      },
    ]

    entrypoint = [
      "/bin/sh",
      "-c",
      "${join("\n", local.constellation_config_commands)}",
    ]

    dockerLabels = "${local.common_tags}"
  }

  constellation_run_container_definition = {
    name      = "${local.tx_privacy_engine_run_container_name}"
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
        sourceContainer = "${local.node_key_bootstrap_container_name}"
      },
      {
        sourceContainer = "${local.metadata_bootstrap_container_name}"
      },
      {
        sourceContainer = "${local.tx_privacy_engine_bootstrap_container_name}"
      },
    ]

    healthCheck = {
      interval = 5
      retries  = 10

      command = [
        "CMD-SHELL",
        "[ -S ${local.tx_privacy_engine_socket_file} ];",
      ]
    }

    command = [
      "${local.constellation_config_file}",
    ]

    dockerLabels = "${local.common_tags}"
  }
}
