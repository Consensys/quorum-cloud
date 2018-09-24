output "message" {
  value = <<msg
Completed!

Region       : ${var.region}
Deployment ID: ${local.deployment_id}

Generated ... ${local.tfinit_filename}
Generated ... ${local.tfvars_filename}

Now you can do `terraform init -backend-config=${local.tfinit_filename} -reconfigure` from ${dirname(local_file.tfinit.filename)}
msg
}
