locals {
  tessera_config_file = "${local.shared_volume_container_path}/tessera.cfg"
  tessera_port        = 9000
  tessera_command     = "java -jar /tessera/tessera-app.jar"

  tessera_config_commands = [
    "apk update",
    "apk add jq",
    "cd ${local.shared_volume_container_path}; echo \"\n\" | ${local.tessera_command} -keygen ${local.shared_volume_container_path}/",
    "export HOST_IP=$(cat ${local.host_ip_file})",
    "export TM_PUB=$(cat ${local.shared_volume_container_path}/.pub)",
    "export TM_KEY=$(cat ${local.shared_volume_container_path}/.key)",
    "echo \"\nHost IP: $HOST_IP\"",
    "echo \"Public Key: $TM_PUB\"",
    "all=\"\"; for f in `ls ${local.hosts_folder} | grep -v ${local.normalized_host_ip}`; do ip=$(cat ${local.hosts_folder}/$f); all=\"$all,{ \\\"url\\\": \\\"http://$ip:${local.tessera_port}/\\\" }\"; done",
    "all=\"[{ \\\"url\\\": \\\"http://$HOST_IP:${local.tessera_port}/\\\" }$all]\"",
    "echo \"Creating ${local.tessera_config_file}\"",
    "echo '${replace(jsonencode(local.tessera_config), "/\"(true|false|[0-9]+)\"/", "$1")}' | jq \". + { peer: $all, keys: { keyData: [ { config: $TM_KEY, publicKey: \\\"$TM_PUB\\\" } ] } } | .server=.server + { hostName: \\\"http://$HOST_IP\\\" }\" > ${local.tessera_config_file}",
    "cat ${local.tessera_config_file}",
  ]

  tessera_config = {
    useWhiteList = false

    jdbc = {
      username = "sa"
      password = ""
      url      = "jdbc:h2:${local.quorum_data_dir}/db;MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0"
    }

    server = {
      port     = "${local.tessera_port}"
      hostName = "to be updated"

      sslConfig = {
        tls                          = "OFF"
        generateKeyStoreIfNotExisted = true
        serverKeyStore               = "${local.quorum_data_dir}/server-keystore"
        serverKeyStorePassword       = "quorum"
        serverTrustStore             = "${local.quorum_data_dir}/server-truststore"
        serverTrustStorePassword     = "quorum"
        serverTrustMode              = "TOFU"
        knownClientsFile             = "${local.quorum_data_dir}/knownClients"
        clientKeyStore               = "${local.quorum_data_dir}/client-keystore"
        clientKeyStorePassword       = "quorum"
        clientTrustStore             = "${local.quorum_data_dir}/client-truststore"
        clientTrustStorePassword     = "quorum"
        clientTrustMode              = "TOFU"
        knownServersFile             = "${local.quorum_data_dir}/knownServers"
      }
    }

    peer = ["to be updated"]

    keys = {
      passwords = []

      keyData = [
        {
          config    = "to be updated"
          publicKey = "to be updated"
        },
      ]
    }

    alwaysSendTo   = []
    unixSocketFile = "${local.tx_privacy_engine_socket_file}"
  }

  tessera_run_commands = [
    "set -e",
    "echo Wait until metadata bootstrap completed ...",
    "while [ ! -f \"${local.metadata_bootstrap_container_status_file}\" ]; do sleep 1; done",
    "${local.tessera_config_commands}",
    "${local.tessera_command} -configfile ${local.tessera_config_file}",
  ]

  tessera_run_container_definition = {
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
        containerPort = "${local.tessera_port}"
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
      interval = 5
      retries  = 10
      timeout  = 5

      command = [
        "CMD-SHELL",
        "[ -S ${local.tx_privacy_engine_socket_file} ];",
      ]
    }

    entrypoint = [
      "/bin/sh",
      "-c",
      "${join("\n", local.tessera_run_commands)}",
    ]

    dockerLabels = "${local.common_tags}"

    cpu = 0
  }
}
