output "status" {
  value = <<MSG
Completed!

Quorum Docker Image         = ${local.quorum_docker_image}
Privacy Engine Docker Image = ${local.tx_privacy_engine_docker_image}

ECS Cluster     = ${aws_ecs_cluster.quorum.name}
Number of Nodes = ${var.number_of_nodes}
MSG
}
