output "network_name" {
  value = "${var.network_name}"
}

output "ecs_cluster_name" {
  value = "${aws_ecs_cluster.quorum.name}"
}

output "chain_id" {
  value = "${random_integer.network_id.result}"
}

output "private_key_file" {
  value = "${local_file.private_key.filename}"
}

output "bucket_name" {
  value = "${aws_s3_bucket.quorum.bucket}"
}

output "status" {
  value = <<MSG
Completed!

Quorum Docker Image         = ${local.quorum_docker_image}
Privacy Engine Docker Image = ${local.tx_privacy_engine_docker_image}
Quorum Network Name         = ${var.network_name}
Number of Quorum Nodes      = ${var.number_of_nodes}
ECS Cluster                 = ${aws_ecs_cluster.quorum.name}
ECS Task Revision           = ${aws_ecs_task_definition.quorum.revision}
CloudWatch Log Group        = ${aws_cloudwatch_log_group.quorum.name}
Bastion Private Key File    = ${local_file.private_key.filename}
Bastion Host Public IP      = ${aws_instance.bastion.public_ip}
Bastion Host Public DNS     = ${aws_instance.bastion.public_dns}
MSG
}
