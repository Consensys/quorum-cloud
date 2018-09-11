### `prepareEnvironment`

This is to pave an environment with resources required for deployment. 

This has to be run once **per AWS Account and per region**.

```
aws cloud-formation create-stack --stack-name quorum-prepare-environment --template-body file://./quorum-prepare-environment.cfn.yml
```

* A S3 bucket to store Terraform state with default server-side-encryption enabled
* A KMS Key to encrypt objects stored in the above S3 bucket

These above resources are exposed to CloudFormation Exports which will be used in subsequent Terraform executions

### `_terraform_init`

This is to generate the backend configuration for `terraform init` by reading various CloudFormation Exports (from the above) and writing to a file.

```
terraform init
terraform apply -auto-approve
```