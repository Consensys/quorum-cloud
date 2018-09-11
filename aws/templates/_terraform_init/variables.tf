variable "region" {
  description = "Target AWS Region"
  default     = "us-east-1"
}

variable "deployment_id" {
  description = "Name of this Quorum deployment. This will be used as a S3 object key to store the Quorum deployment state"
}
