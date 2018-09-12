variable "region" {
  description = "Target AWS Region. This must be pre-initialized from `_terraform_init` run"
}

variable "deployment_id" {
  description = "Identify the Quorum network from multiple deployments. This must be pre-initialized from `_terraform_init` run"
}

variable "number_of_nodes" {
  description = "Number of Quorum nodes. Default is 7"
  default     = "7"
}

variable "subnet_ids" {
  type        = "list"
  description = "List of subnet ids used by ECS to create instances. These subnets must be routable to the internet, via Internet Gateway or NAT instance"
}

variable "is_igw_subnets" {
  description = "Indicate that if subnets supplied in subnet_ids are routable to the internet via Internet Gateway"
}

variable "quorum_docker_image" {
  description = "URL to Quorum docker image to be used"
  default     = "quorumengineering/quorum"
}

variable "quorum_docker_image_tag" {
  description = "Quorum Docker image tag to be used"
  default     = "latest"
}

variable "constellation_docker_image" {
  description = "URL to Constellation docker image to be used. Only needed if tx_privacy_engine is constellation"
  default     = "quorumengineering/constellation"
}

variable "constellation_docker_image_tag" {
  description = "Constellation Docker image tag to be used"
  default     = "latest"
}

variable "tessera_docker_image" {
  description = "URL to Constellation docker image to be used. Only needed if tx_privacy_engine is constellation"
  default     = "quorumengineering/tessera"
}

variable "tessera_docker_image_tag" {
  description = "Tessera Docker image tag to be used"
  default     = "latest"
}

variable "concensus_mechanism" {
  description = "Concensus mechanism used in the network. Supported values are raft/istanbul"
  default     = "raft"
}

variable "tx_privacy_engine" {
  description = "Engine that implements transaction privacy. Supported values are constellation/tessera"
  default     = "constellation"
}