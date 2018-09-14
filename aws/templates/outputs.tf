output "network_name" {
  value = "${var.network_name}"
}

output "ecs_cluster_name" {
  value = "${aws_ecs_cluster.quorum.name}"
}

output "status" {
  value = <<MSG
Completed!

Quorum Docker Image         = ${local.quorum_docker_image}
Privacy Engine Docker Image = ${local.tx_privacy_engine_docker_image}
Quorum Deployment ID        = ${var.network_name}
Number of Quorum Nodes      = ${var.number_of_nodes}
ECS Cluster                 = ${aws_ecs_cluster.quorum.name}
ECS Task Revision           = ${aws_ecs_task_definition.quorum.revision}
CloudWatch Log Group        = ${aws_cloudwatch_log_group.quorum.name}
MSG
}
