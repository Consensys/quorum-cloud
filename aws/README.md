## Deployment Architecture

TBD

### ECS Containers

* ECS Services: number of services is equal to number of nodes in the network
* ECS Task: defines the following containers
  ```
        node-key-bootstrap
                ^
                |
        metadata-bootstrap
                ^
              /   \
             /     \
  quorum-run  --> {tx-privacy-engine}-run
             
  ```
  * `node-key-bootstrap`: run `bootnode` to generate a node key and marshall to node id, store them in shared folder
  * `metadata-bootstrap`: prepare IP list and enode list
  * `{tx-privacy-engine}-run`: run Constellation/Tessera
  * `quorum-run`: run `geth`

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

This is to generate the backend configuration for `terraform init` by reading various CloudFormation Exports (from the above) 
and writing to files (`terraform.auto.backend-config` and `terraform.auto.tfvars`) that are used for Step 3

```
terraform init
terraform apply -auto-approve
```

### Step 3: Provisioning Quorum

```
terraform init -backend-config=terraform.auto.backend-config
terraform plan -out quorum.tfplan -var network_name=dev
terraform apply quorum.tfplan
```

If `network_name` is not provided, a random name will be generated.

After provisioning is finished, public DNS and IP of the bastion host will be output along with path to the SSH Private Key.
Bastion Host is pre-configured with Docker and Quorum Docker Image which can be used to perform `geth attach`.
To ssh to Bastion Host: run `ssh -i quorum.pem ec2-user@<bastion DNS/IP>`. 

If you wish to run `geth attach`, tunelling via SSH, to Node1:  run `ssh -t -i quorum.pem ec2-user@<bastion DNS/IP> Node1`

## Logging

CloudWatch Log Group `/ecs/quorum/**`
