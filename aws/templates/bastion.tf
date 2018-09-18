locals {
  default_bastion_resource_name = "${format("quorum-bastion-%s", var.network_name)}"
}

data "aws_ami" "this" {
  most_recent = true

  filter {
    name = "name"
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
  filename = "${path.module}/quorum.pem"
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

yum -y update
yum -y install docker
systemctl enable docker
systemctl start docker
docker pull ${local.quorum_docker_image}

mkdir -p /qdata
aws s3 cp --recursive s3://${local.s3_revision_folder}/ /qdata/

EOF

  tags = "${merge(local.common_tags, map("Name", local.default_bastion_resource_name))}"
}
