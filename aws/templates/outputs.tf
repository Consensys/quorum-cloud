output "status" {
  value = <<MSG
Completed!

Quorum Docker Image         = ${local.quorum_docker_image}
Privacy Engine Docker Image = ${local.tx_privacy_engine_docker_image}
Quorum Deployment ID        = ${var.deployment_id}
Number of Quorum Nodes      = ${var.number_of_nodes}
ECS Cluster                 = ${aws_ecs_cluster.quorum.name}
CloudWatch Log Group        = ${aws_cloudwatch_log_group.quorum.name}
MSG
}
