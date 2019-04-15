locals {
  default_bastion_resource_name = "${format("quorum-bastion-%s", var.network_name)}"
  ethstats_docker_image = "puppeth/ethstats:latest"
  ethstats_port = 3000
}

data "aws_ami" "this" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*",
    ]
  }

  filter {
    name = "virtualization-type"

    values = [
      "hvm",
    ]
  }

  filter {
    name = "architecture"

    values = [
      "x86_64",
    ]
  }

  owners = [
    "137112412989",
  ]

  # amazon
}

resource "random_id" "ethstat_secret" {
  byte_length = 16
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits = "2048"
}

resource "aws_key_pair" "ssh" {
  public_key = "${tls_private_key.ssh.public_key_openssh}"
  key_name = "${local.default_bastion_resource_name}"
}

resource "local_file" "private_key" {
  filename = "${path.module}/quorum-${var.network_name}.pem"
  content = "${tls_private_key.ssh.private_key_pem}"
  provisioner "local-exec" {
    on_failure = "continue"
    command = "chmod 600 ${self.filename}"
  }
}

resource "aws_instance" "bastion" {
  ami = "${data.aws_ami.this.id}"
  instance_type = "t2.large"

  vpc_security_group_ids = [
    "${aws_security_group.quorum.id}",
    "${aws_security_group.bastion-ssh.id}",
    "${aws_security_group.bastion-ethstats.id}",
  ]

  subnet_id = "${var.bastion_public_subnet_id}"
  associate_public_ip_address = "true"
  key_name = "${aws_key_pair.ssh.key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.bastion.name}"

  user_data = <<EOF
#!/bin/bash

set -e

# START: added per suggestion from AWS support to mitigate an intermittent failures from yum update
sleep 20
yum clean all
yum repolist
# END

yum -y update
yum -y install jq
amazon-linux-extras install docker -y
systemctl enable docker
systemctl start docker
docker pull ${local.quorum_docker_image}
docker run -d -e "WS_SECRET=${random_id.ethstat_secret.hex}" -p ${local.ethstats_port}:${local.ethstats_port} ${local.ethstats_docker_image}

EOF

  tags = "${merge(local.common_tags, map("Name", local.default_bastion_resource_name))}"
}

resource "local_file" "bootstrap" {
  filename = "${path.module}/generated-bootstrap.sh"

  content = <<EOF
#!/bin/bash

set -e

export AWS_DEFAULT_REGION=${var.region}
export TASK_REVISION=${aws_ecs_task_definition.quorum.revision}
sudo rm -rf ${local.shared_volume_container_path}
sudo mkdir -p ${local.shared_volume_container_path}/mappings
sudo mkdir -p ${local.privacy_addresses_folder}

count=0
while [ $count -lt ${var.number_of_nodes} ]
do
  count=$(ls ${local.privacy_addresses_folder} | grep ^ip | wc -l)
  sudo aws s3 cp --recursive s3://${local.s3_revision_folder}/ ${local.shared_volume_container_path}/ > /dev/null 2>&1 \
    | echo Wait for nodes in Quorum network being up ... $count/${var.number_of_nodes}
  sleep 1
done

if which jq >/dev/null; then
  echo "Found jq"
else
  echo "jq not found. Instaling ..."
  sudo yum -y install jq
fi

for t in `aws ecs list-tasks --cluster ${local.ecs_cluster_name} | jq -r .taskArns[]`
do
  task_metadata=$(aws ecs describe-tasks --cluster ${local.ecs_cluster_name} --tasks $t)
  HOST_IP=$(echo $task_metadata | jq -r '.tasks[0] | .containers[] | select(.name == "${local.quorum_run_container_name}") | .networkInterfaces[] | .privateIpv4Address')
  group=$(echo $task_metadata | jq -r '.tasks[0] | .group')
  taskArn=$(echo $task_metadata | jq -r '.tasks[0] | .taskDefinitionArn')
  # only care about new task
  if [[ "$taskArn" == *:$TASK_REVISION ]]; then
     echo $group | sudo tee ${local.shared_volume_container_path}/mappings/${local.normalized_host_ip}
  fi
done

cat <<SS | sudo tee ${local.shared_volume_container_path}/quorum_metadata
quorum:
  nodes:
SS
nodes=(${join(" ", aws_ecs_service.quorum.*.name)})
cd ${local.shared_volume_container_path}/mappings
for idx in "$${!nodes[@]}"
do
  f=$(grep -l $${nodes[$idx]} *)
  ip=$(cat ${local.hosts_folder}/$f)
  nodeIdx=$((idx+1))
  script="/usr/local/bin/Node$nodeIdx"
  cat <<SS | sudo tee $script
#!/bin/bash

sudo docker run --rm -it ${local.quorum_docker_image} attach http://$ip:${local.quorum_rpc_port} $@
SS
  sudo chmod +x $script
  cat <<SS | sudo tee -a ${local.shared_volume_container_path}/quorum_metadata
    Node$nodeIdx:
      privacy-address: $(cat ${local.privacy_addresses_folder}/$f)
      url: http://$ip:${local.quorum_rpc_port}
      third-party-url: http://$ip:${local.tessera_thirdparty_port}
SS
done
EOF
}

resource "null_resource" "bastion_remote_exec" {
  triggers {
    bastion = "${aws_instance.bastion.public_dns}"
    ecs_task_definition = "${aws_ecs_task_definition.quorum.revision}"
    script = "${md5(local_file.bootstrap.content)}"
  }

  provisioner "remote-exec" {
    script = "${local_file.bootstrap.filename}"

    connection {
      host = "${aws_instance.bastion.public_ip}"
      user = "ec2-user"
      private_key = "${tls_private_key.ssh.private_key_pem}"
      timeout = "10m"
    }
  }
}
