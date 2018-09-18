locals {
  default_bastion_resource_name = "${format("quorum-bastion-%s", var.network_name)}"
}

data "aws_ami" "this" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # amazon
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "aws_key_pair" "ssh" {
  public_key = "${tls_private_key.ssh.public_key_openssh}"
  key_name   = "${local.default_bastion_resource_name}"
}

resource "local_file" "private_key" {
  filename = "${path.module}/quorum-${var.network_name}.pem"
  content  = "${tls_private_key.ssh.private_key_pem}"
}

resource "aws_instance" "bastion" {
  ami                         = "${data.aws_ami.this.id}"
  instance_type               = "t2.large"
  vpc_security_group_ids      = ["${aws_security_group.quorum.id}", "${aws_security_group.bastion.id}"]
  subnet_id                   = "${var.bastion_public_subnet_id}"
  associate_public_ip_address = "true"
  key_name                    = "${aws_key_pair.ssh.key_name}"
  iam_instance_profile        = "${aws_iam_instance_profile.bastion.name}"

  user_data = <<EOF
#!/bin/bash

set -e

yum -y update
yum -y install jq
yum -y install docker
systemctl enable docker
systemctl start docker
docker pull ${local.quorum_docker_image}

export AWS_DEFAULT_REGION=${var.region}
export TASK_REVISION=${aws_ecs_task_definition.quorum.revision}
mkdir -p ${local.shared_volume_container_path}/mappings

count=0
while [ $count -lt ${var.number_of_nodes} ]
do
  aws s3 cp --recursive s3://${local.s3_revision_folder}/ ${local.shared_volume_container_path}/
  count=$(ls ${local.hosts_folder} | grep ^ip | wc -l)
  echo Wait for nodes in Quorum network being up ... $count/${var.number_of_nodes}
  sleep 1;
done

for t in `aws ecs list-tasks --cluster ${local.ecs_cluster_name} | jq -r .taskArns[]`
do
  task_metadata=$(aws ecs describe-tasks --cluster ${local.ecs_cluster_name} --tasks $t)
  HOST_IP=$(echo $task_metadata | jq -r '.tasks[0] | .containers[] | select(.name == "${local.quorum_run_container_name}") | .networkInterfaces[] | .privateIpv4Address')
  group=$(echo $task_metadata | jq -r '.tasks[0] | .group')
  echo $group > ${local.shared_volume_container_path}/mappings/${local.normalized_host_ip}
done

nodes=(${join(" ", aws_ecs_service.quorum.*.name)})
cd ${local.shared_volume_container_path}/mappings
for idx in "$${!nodes[@]}"
do
  f=$(grep -l $${nodes[$idx]} *)
  ip=$(cat ${local.hosts_folder}/$f)
  script="/usr/local/bin/Node$((idx+1))"
  echo "sudo docker run --rm -it ${local.quorum_docker_image} attach http://$ip:${local.quorum_rpc_port}" > $script
  chmod +x $script
done

EOF

  tags = "${merge(local.common_tags, map("Name", local.default_bastion_resource_name))}"
}
