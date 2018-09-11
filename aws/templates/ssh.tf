resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "local_file" "private_key" {
  filename          = "${path.module}/quorum.pem"
  sensitive_content = "${tls_private_key.ssh.private_key_pem}"
}

resource "aws_key_pair" "ssh" {
  public_key = "${tls_private_key.ssh.public_key_openssh}"
  key_name   = "quorum-ssh-${var.deployment_id}"
}
