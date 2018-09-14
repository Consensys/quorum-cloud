locals {
  host_ip_file       = "${local.shared_volume_container_path}/host_ip"
  task_revision_file = "${local.shared_volume_container_path}/task_revision"
  hosts_folder       = "${local.shared_volume_container_path}/hosts"

  metadata_bootstrap_container_status_file = "${local.shared_volume_container_path}/metadata_bootstrap_container_status"

  // For S3 related operations
  s3_revision_folder = "${local.quorum_bucket}/rev_$TASK_REVISION"
  normalized_host_ip = "ip_$(echo $HOST_IP | sed -e 's/\\./_/g')"

  node_key_bootstrap_commands = [
    "mkdir -p ${local.quorum_data_dir}/geth",
    "echo \"\" > ${local.quorum_password_file}",
    "bootnode -genkey ${local.quorum_data_dir}/geth/nodekey",
    "export NODE_ID=$(bootnode -nodekey ${local.quorum_data_dir}/geth/nodekey -writeaddress)",
    "echo Write Node Id [$NODE_ID] to ${local.node_id_file}",
    "echo $NODE_ID > ${local.node_id_file}",
  ]

  node_key_bootstrap_container_definition = {
    name      = "${local.node_key_bootstrap_container_name}"
    image     = "${local.quorum_docker_image}"
    essential = "false"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region        = "${var.region}"
        awslogs-stream-prefix = "${var.network_name}"
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
        "[ -f ${local.node_id_file} ];",
      ]
    }

    entrypoint = [
      "/bin/sh",
      "-c",
      "${join("\n", local.node_key_bootstrap_commands)}",
    ]

    dockerLabels = "${local.common_tags}"
  }

  metadata_bootstrap_commands = [
    "set -e",
    "echo Wait until Node Key is ready ...",
    "while [ ! -f \"${local.node_id_file}\" ]; do sleep 1; done",
    "apk update",
    "apk add curl jq",
    "export TASK_REVISION=$(curl -s 169.254.170.2/v2/metadata | jq '.Revision' -r)",
    "echo \"Task Revision: $TASK_REVISION\"",
    "echo $TASK_REVISION > ${local.task_revision_file}",
    "export HOST_IP=$(curl -s 169.254.170.2/v2/metadata | jq '.Containers[] | select(.Name == \"${local.metadata_bootstrap_container_name}\") | .Networks[] | select(.NetworkMode == \"awsvpc\") | .IPv4Addresses[0]' -r )",
    "echo \"Host IP: $HOST_IP\"",
    "echo $HOST_IP > ${local.host_ip_file}",
    "mkdir -p ${local.hosts_folder}",
    "mkdir -p ${local.node_ids_folder}",
    "aws s3 cp ${local.node_id_file} s3://${local.s3_revision_folder}/nodeids/${local.normalized_host_ip} --sse aws:kms --sse-kms-key-id ${var.quorum_bucket_kms_key_arn}",
    "aws s3 cp ${local.host_ip_file} s3://${local.s3_revision_folder}/hosts/${local.normalized_host_ip} --sse aws:kms --sse-kms-key-id ${var.quorum_bucket_kms_key_arn}",

    // Gather all IPs
    "count=0; while [ $count -lt ${var.number_of_nodes} ]; do aws s3 cp --recursive s3://${local.s3_revision_folder}/hosts ${local.hosts_folder}; count=$(ls ${local.hosts_folder} | grep ^ip | wc -l); echo \"Wait for other containers to report their IPs ... $count/${var.number_of_nodes}\"; sleep 1; done",

    "echo \"All containers have reported their IPs\"",

    // Gather all Node IDs
    "count=0; while [ $count -lt ${var.number_of_nodes} ]; do aws s3 cp --recursive s3://${local.s3_revision_folder}/nodeids ${local.node_ids_folder}; count=$(ls ${local.node_ids_folder} | grep ^ip | wc -l); echo \"Wait for other nodes to report their IDs ... $count/${var.number_of_nodes}\"; sleep 1; done",

    "echo \"All nodes have registered their IDs\"",
    "echo \"Done!\" > ${local.metadata_bootstrap_container_status_file}",
  ]

  metadata_bootstrap_container_definition = {
    name      = "${local.metadata_bootstrap_container_name}"
    image     = "${local.aws_cli_docker_image}"
    essential = "false"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region        = "${var.region}"
        awslogs-stream-prefix = "${var.network_name}"
      }
    }

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
    ]

    healthCheck = {
      interval = 5
      retries  = 10

      command = [
        "CMD-SHELL",
        "[ -f ${local.metadata_bootstrap_container_status_file} ];",
      ]
    }

    entryPoint = [
      "/bin/sh",
      "-c",
      "${join("\n", local.metadata_bootstrap_commands)}",
    ]

    dockerLabels = "${local.common_tags}"
  }
}
