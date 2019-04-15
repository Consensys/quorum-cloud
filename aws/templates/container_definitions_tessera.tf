locals {
  tessera_config_file = "${local.shared_volume_container_path}/tessera.cfg"
  tessera_port = 9000
  tessera_thirdparty_port = 9080
  tessera_command = "java -jar /tessera/tessera-app.jar"
  tessera_pub_key_file = "${local.shared_volume_container_path}/.pub"

  tessera_config_commands = [
    "apk update",
    "apk add jq",
    "cd ${local.shared_volume_container_path}; echo \"\n\" | ${local.tessera_command} -keygen ${local.shared_volume_container_path}/",
    "export HOST_IP=$(cat ${local.host_ip_file})",
    "export TM_PUB=$(cat ${local.tessera_pub_key_file})",
    "export TM_KEY=$(cat ${local.shared_volume_container_path}/.key)",
    "echo \"\nHost IP: $HOST_IP\"",
    "echo \"Public Key: $TM_PUB\"",
    "all=\"\"; for f in `ls ${local.hosts_folder} | grep -v ${local.normalized_host_ip}`; do ip=$(cat ${local.hosts_folder}/$f); all=\"$all,{ \\\"url\\\": \\\"http://$ip:${local.tessera_port}/\\\" }\"; done",
    "all=\"[{ \\\"url\\\": \\\"http://$HOST_IP:${local.tessera_port}/\\\" }$all]\"",
    "export TESSERA_VERSION=${var.tessera_docker_image_tag}",
    "export V=$(echo -e \"0.8\n$TESSERA_VERSION\" | sort -n -r -t '.' -k 1,1 -k 2,2 | head -n1)",
    "echo \"Creating ${local.tessera_config_file}\"",
    <<SCRIPT
DDIR=${local.quorum_data_dir}
unzip -p /tessera/tessera-app.jar META-INF/MANIFEST.MF | grep Tessera-Version | cut -d: -f2 | xargs
echo "Tessera Version: $TESSERA_VERSION"
V08=$$(echo -e "0.8\n$TESSERA_VERSION" | sort -n -r -t '.' -k 1,1 -k 2,2 | head -n1)
V09=$$(echo -e "0.9\n$TESSERA_VERSION" | sort -n -r -t '.' -k 1,1 -k 2,2 | head -n1)
case "$TESSERA_VERSION" in
    "$V09"|latest)
    # use new config
    cat <<EOF > ${local.tessera_config_file}
{
  "useWhiteList": false,
  "jdbc": {
    "username": "sa",
    "password": "",
    "url": "jdbc:h2:./$${DDIR}/db;MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0",
    "autoCreateTables": true
  },
  "serverConfigs":[
  {
    "app":"ThirdParty",
    "enabled": true,
    "serverAddress": "http://$HOST_IP:${local.tessera_thirdparty_port}",
    "communicationType" : "REST"
  },
  {
    "app":"Q2T",
    "enabled": true,
    "serverAddress": "unix:${local.tx_privacy_engine_socket_file}",
    "communicationType" : "REST"
  },
  {
    "app":"P2P",
    "enabled": true,
    "serverAddress": "http://$HOST_IP:${local.tessera_port}",
    "sslConfig": {
      "tls": "OFF",
      "generateKeyStoreIfNotExisted": true,
      "serverKeyStore": "$${DDIR}/server-keystore",
      "serverKeyStorePassword": "quorum",
      "serverTrustStore": "$${DDIR}/server-truststore",
      "serverTrustStorePassword": "quorum",
      "serverTrustMode": "TOFU",
      "knownClientsFile": "$${DDIR}/knownClients",
      "clientKeyStore": "$${DDIR}/client-keystore",
      "clientKeyStorePassword": "quorum",
      "clientTrustStore": "$${DDIR}/client-truststore",
      "clientTrustStorePassword": "quorum",
      "clientTrustMode": "TOFU",
      "knownServersFile": "$${DDIR}/knownServers"
    },
    "communicationType" : "REST"
  }
  ],
  "peer": $all,
  "keys": {
    "passwords": [],
    "keyData": [
      {
        "config": $TM_KEY,
        "publicKey": "$TM_PUB"
      }
    ]
  },
  "alwaysSendTo": []
}
EOF    
      ;;
    "$V08")
      # use enhanced config
      cat <<EOF > ${local.tessera_config_file}
{
  "useWhiteList": false,
  "jdbc": {
    "username": "sa",
    "password": "",
    "url": "jdbc:h2:./$${DDIR}/db;MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0",
    "autoCreateTables": true
  },
  "serverConfigs":[
  {
    "app":"ThirdParty",
    "enabled": true,
    "serverSocket":{
      "type":"INET",
      "port": ${local.tessera_thirdparty_port},
      "hostName": "http://$HOST_IP"
    },
    "communicationType" : "REST"
  },
  {
    "app":"Q2T",
    "enabled": true,
    "serverSocket":{
      "type":"UNIX",
      "path":"${local.tx_privacy_engine_socket_file}"
    },
    "communicationType" : "UNIX_SOCKET"
  },
  {
    "app":"P2P",
    "enabled": true,
    "serverSocket":{
      "type":"INET",
      "port": ${local.tessera_port},
      "hostName": "http://$HOST_IP"
    },
    "sslConfig": {
      "tls": "OFF",
      "generateKeyStoreIfNotExisted": true,
      "serverKeyStore": "$${DDIR}/server-keystore",
      "serverKeyStorePassword": "quorum",
      "serverTrustStore": "$${DDIR}/server-truststore",
      "serverTrustStorePassword": "quorum",
      "serverTrustMode": "TOFU",
      "knownClientsFile": "$${DDIR}/knownClients",
      "clientKeyStore": "$${DDIR}/client-keystore",
      "clientKeyStorePassword": "quorum",
      "clientTrustStore": "$${DDIR}/client-truststore",
      "clientTrustStorePassword": "quorum",
      "clientTrustMode": "TOFU",
      "knownServersFile": "$${DDIR}/knownServers"
    },
    "communicationType" : "REST"
  }
  ],
  "peer": $all,
  "keys": {
    "passwords": [],
    "keyData": [
      {
        "config": $TM_KEY,
        "publicKey": "$TM_PUB"
      }
    ]
  },
  "alwaysSendTo": []
}
EOF
      ;;
    *)
    # use old config
    cat <<EOF > ${local.tessera_config_file}
{
    "useWhiteList": false,
    "jdbc": {
        "username": "sa",
        "password": "",
        "url": "jdbc:h2:./$${DDIR}/db;MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0",
        "autoCreateTables": true
    },
    "server": {
        "port": 9000,
        "hostName": "http://$HOST_IP",
        "sslConfig": {
            "tls": "OFF",
            "generateKeyStoreIfNotExisted": true,
            "serverKeyStore": "$${DDIR}/server-keystore",
            "serverKeyStorePassword": "quorum",
            "serverTrustStore": "$${DDIR}/server-truststore",
            "serverTrustStorePassword": "quorum",
            "serverTrustMode": "TOFU",
            "knownClientsFile": "$${DDIR}/knownClients",
            "clientKeyStore": "$${DDIR}/client-keystore",
            "clientKeyStorePassword": "quorum",
            "clientTrustStore": "$${DDIR}/client-truststore",
            "clientTrustStorePassword": "quorum",
            "clientTrustMode": "TOFU",
            "knownServersFile": "$${DDIR}/knownServers"
        }
    },
    "peer": $all,
    "keys": {
        "passwords": [],
        "keyData": [
            {
                "config": $TM_KEY,
                "publicKey": "$TM_PUB"
            }
        ]
    },
    "alwaysSendTo": [],
    "unixSocketFile": "${local.tx_privacy_engine_socket_file}"
}
EOF
      ;;
esac
cat ${local.tessera_config_file}
SCRIPT
  ]

  tessera_run_commands = [
    "set -e",
    "echo Wait until metadata bootstrap completed ...",
    "while [ ! -f \"${local.metadata_bootstrap_container_status_file}\" ]; do sleep 1; done",
    "${local.tessera_config_commands}",
    "${local.tessera_command} -configfile ${local.tessera_config_file}",
  ]

  tessera_run_container_definition = {
    name = "${local.tx_privacy_engine_run_container_name}"
    image = "${local.tx_privacy_engine_docker_image}"
    essential = "false"

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group = "${aws_cloudwatch_log_group.quorum.name}"
        awslogs-region = "${var.region}"
        awslogs-stream-prefix = "logs"
      }
    }

    portMappings = [
      {
        containerPort = "${local.tessera_port}"
      },
      {
        containerPort = "${local.tessera_thirdparty_port}"
      },
    ]

    mountPoints = [
      {
        sourceVolume = "${local.shared_volume_name}"
        containerPath = "${local.shared_volume_container_path}"
      },
    ]

    volumesFrom = [
      {
        sourceContainer = "${local.metadata_bootstrap_container_name}"
      },
    ]

    healthCheck = {
      interval = 30
      retries = 10
      timeout = 60
      startPeriod = 300

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
