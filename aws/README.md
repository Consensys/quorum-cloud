Deploy Quorum Network in AWS using ECS Fargate, S3 and an EC2

## Deployment Architecture

```
                   +----- Public Subnet -----+       +----- Private Subnet(s) ---+
                   |                         |       |                           |
Internet <--- [NAT Gateway]     [Bastion] ---------->|  [ECS] [ECS] [ECS] ....   |
                 ^ |                         |       |                           |
                 | +-------------------------+       +-------------.-------------+
                 |                                                 |
                 +------------------- Routable --------------------+ 
```

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

**Note**: AWS Fargate is only supported in certain regions, see [AWS Region Table](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) for more details.

```
aws cloudformation create-stack --stack-name quorum-prepare-environment --template-body file://./quorum-prepare-environment.cfn.yml
```

* A S3 bucket to store Terraform state with default server-side-encryption enabled
* A KMS Key to encrypt objects stored in the above S3 bucket

These above resources are exposed to CloudFormation Exports which will be used in subsequent Terraform executions

### Step 2: `_terraform_init`

This is to generate the backend configuration for `terraform init` by reading various CloudFormation Exports (from the above) 
and writing to files (`terraform.auto.backend-config` and `terraform.auto.tfvars`) that are used in **Step 3**

```
terraform init
terraform apply -var network_name=dev -auto-approve
```

If `network_name` is not provided, a random name will be generated.

### Step 3: Provisioning Quorum

The only required inputs are subnets information:
* `subnet_ids`: in which ECS provisions containers. These subnets must be routable to Internet (either they are public subnets by default or private subnets routed via NAT Gateway)
* `is_igw_subnets`: `true` if the above `subnet_ids` are attached with Internet Gateway, `false` otherwise
* `bastion_public_subnet_id`: where Bastion node lives. This must be a public subnet

By default, new Quorum network will be using Raft as the consensus mechanism and Tessera as the privacy engine. 
These can be customized via `consensus_mechanism` and `tx_privacy_engine` variables.

Also provide additional CIDR blocks so you can access bastion node via `access_bastion_cidr_blocks` variable

Prepare `terraform.tfvars` as sample below:
```
is_igw_subnets = "false"

# private subnets routable to Internet via NAT Gateway
subnet_ids = [
  "subnet-4c30c605",
  "subnet-4c30c605",
  "subnet-09263334",
  "subnet-5236300a",
]

bastion_public_subnet_id = "subnet-3a8d8707"

consensus_mechanism = "istanbul"

# tx_privacy_engine = "constellation"

# access_bastion_cidr_blocks = [
#   "190.190.190.190/32",
# ]
```

Run Terraform

```
terraform init -backend-config=terraform.auto.backend-config -reconfigure
terraform plan -out quorum.tfplan
terraform apply quorum.tfplan
```

During the `terraform init`, you may be asked if you want to copy existing state to the new backend, enter 'no'. 
This happens when you switch between Quorum deployments.

After provisioning is finished, public DNS and IP of the bastion host will be output along with path to the SSH Private Key.
Bastion Host is pre-configured with Docker and Quorum Docker Image which can be used to perform `geth attach`.
To ssh to Bastion Host: run `ssh -i <private key file> ec2-user@<Bastion DNS/IP>`.

If you wish to run `geth attach`, tunelling via SSH, to Node1:  run `ssh -t -i <private key file> ec2-user@<bastion DNS/IP> Node1`

## Logging

CloudWatch Log Group `/ecs/quorum/**`
