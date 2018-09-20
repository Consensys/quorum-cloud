locals {
  constellation_config_file  = "${local.shared_volume_container_path}/constellation.cfg"
  constellation_port         = 10000
  constellation_pub_key_file = "${local.shared_volume_container_path}/tm.pub"

  constellation_config_commands = [
    "constellation-node --generatekeys=${local.shared_volume_container_path}/tm < /dev/null",
    "export HOST_IP=$(cat ${local.host_ip_file})",
    "echo \"\nHost IP: $HOST_IP\"",
    "echo \"Public Key: $(cat ${local.constellation_pub_key_file})\"",
    "all=\"\"; for f in `ls ${local.hosts_folder} | grep -v ${local.normalized_host_ip}`; do ip=$(cat ${local.hosts_folder}/$f); all=\"$all,\\\"http://$ip:${local.constellation_port}/\\\"\"; done",
    "echo \"Creating ${local.constellation_config_file}\"",
    "echo \"# This file is auto generated. Please do not edit\" > ${local.constellation_config_file}",
    "echo \"url = \\\"http://$HOST_IP:${local.constellation_port}/\\\"\" >> ${local.constellation_config_file}",
    "echo \"port = ${local.constellation_port}\" >> ${local.constellation_config_file}",
    "echo \"socket = \\\"${local.tx_privacy_engine_socket_file}\\\"\" >> ${local.constellation_config_file}",
    "echo \"othernodes = [\\\"http://$HOST_IP:${local.constellation_port}/\\\"$all]\" >> ${local.constellation_config_file}",
    "echo \"publickeys = [\\\"${local.shared_volume_container_path}/tm.pub\\\"]\" >> ${local.constellation_config_file}",
    "echo \"privatekeys = [\\\"${local.shared_volume_container_path}/tm.key\\\"]\" >> ${local.constellation_config_file}",
    "echo \"storage = \\\"/constellation\\\"\" >> ${local.constellation_config_file}",
    "echo \"verbosity = 4\" >> ${local.constellation_config_file}",
    "cat ${local.constellation_config_file}",
  ]

  constellation_run_commands = [
    "set -e",
    "echo Wait until metadata bootstrap completed ...",
    "while [ ! -f \"${local.metadata_bootstrap_container_status_file}\" ]; do sleep 1; done",
    "${local.constellation_config_commands}",
    "constellation-node ${local.constellation_config_file}",
  ]

  constellation_run_container_definition = {
    name      = "${local.tx_privacy_engine_run_container_name}"
    image     = "${local.tx_privacy_engine_docker_image}"
    essential = "false"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region        = "${var.region}"
        awslogs-stream-prefix = "logs"
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
        sourceContainer = "${local.metadata_bootstrap_container_name}"
      },
    ]

    healthCheck = {
      interval    = 30
      retries     = 10
      timeout     = 60
      startPeriod = 300

      command = [
        "CMD-SHELL",
        "[ -S ${local.tx_privacy_engine_socket_file} ];",
      ]
    }

    entrypoint = [
      "/bin/sh",
      "-c",
      "${join("\n", local.constellation_run_commands)}",
    ]

    dockerLabels = "${local.common_tags}"

    cpu = 0
  }
}
