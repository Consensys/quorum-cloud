output "message" {
  value = <<msg
Completed!

Region       : ${var.region}
Deployment ID: ${var.deployment_id}

Generated ${local.filename}

Now you can do `terraform init -backend-config=${local.filename}` from ${dirname(local_file.tfinit.filename)}
msg
}
