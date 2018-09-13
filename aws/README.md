## Deployment Architecture

TBD

### ECS Containers
```
           geth-key-gen
                ^
                |
         config-bootstrap
                ^
              /   \
             /     \
 geth-bootstrap   privacy-engine-bootstrap
        ^                   ^
        |                   |
        |            privacy-engine-run
        |                   ^
        |                   |
        |-------------- geth-run  
             
```


* `geth-key-gen`: run `bootnode` to create a node key, store it in shared folder
* `config-bootstrap`: prepare IP list and enode list
* `geth-bootstrap`: run `geth init`
* `privacy-engine-bootstrap`: prepare config for the engine (Constallation/Tessera config)
* `privacy-engine-run`: run Constellation/Tessera
* `geth-run`: run `geth`

## Getting Started

### Step 1: `prepareEnvironment`

This is to pave an environment with resources required for deployment. 

This has to be run once **per AWS Account and per region**.

```
aws cloud-formation create-stack --stack-name quorum-prepare-environment --template-body file://./quorum-prepare-environment.cfn.yml
```

* A S3 bucket to store Terraform state with default server-side-encryption enabled
* A KMS Key to encrypt objects stored in the above S3 bucket

These above resources are exposed to CloudFormation Exports which will be used in subsequent Terraform executions

### Step 2: `_terraform_init`

This is to generate the backend configuration for `terraform init` by reading various CloudFormation Exports (from the above) and writing to a file.

```
terraform init
terraform apply -auto-approve
```

### Step 3: Provisioning Quorum

```
terraform init -backend-config=terraform.auto.backend-config
terraform plan -out quorum.tfplan
terraform apply quorum.tfplan
```

## Logging

CloudWatch Log Group `/ecs/quorum/**`
