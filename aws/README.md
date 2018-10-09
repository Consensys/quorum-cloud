Deploy Quorum Network in AWS using ECS Fargate, S3 and an EC2

**Note**:
* AWS Fargate is only available in certain regions, see [AWS Region Table](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) for more details.
* AWS Fargate has default limits which might impact the provisioning, see [Amazon ECS Service Limits](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service_limits.html) for more details.


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

This has to be run once **per region and per AWS Account**.

```
aws cloudformation create-stack --stack-name quorum-prepare-environment --template-body file://./quorum-prepare-environment.cfn.yml
```

* A S3 bucket to store Terraform state with default server-side-encryption enabled
* A KMS Key to encrypt objects stored in the above S3 bucket

These above resources are exposed to CloudFormation Exports which will be used in subsequent Terraform executions

### Step 2: Intializing Terraform

```
cd _terraform_init
```
This is to generate the backend configuration for subsequent `terraform init` by reading various CloudFormation Exports (from the above)
and writing to files (`terraform.auto.backend_config` and `terraform.auto.tfvars`) that are used in **Step 3**

```
terraform init
terraform apply -var network_name=dev -var region=us-east-1 -auto-approve
```

If `network_name` is not provided, a random name will be generated.

### Step 3: Provisioning Quorum

The only required inputs are subnets information:
* `subnet_ids`: in which ECS provisions containers. These subnets must be routable to Internet (either they are public subnets by default or private subnets routed via NAT Gateway)
* `is_igw_subnets`: `true` if the above `subnet_ids` are attached with Internet Gateway, `false` otherwise
* `bastion_public_subnet_id`: where Bastion node lives. This must be a public subnet

By default, new Quorum network will be using Raft as the consensus mechanism and Tessera as the privacy engine. 
These can be customized via `consensus_mechanism` and `tx_privacy_engine` variables.

Also provide additional CIDR blocks via `access_bastion_cidr_blocks` variable so you can access bastion node.

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
terraform init -backend-config=terraform.auto.backend_config -reconfigure
terraform apply
```

Once completed, outputs will contain various information including bastion DNS/IP and private key file which can be
used to perform SSH. **Note: you need to do `chmod 600` to the private key file**

Now you can do `geth attach` to any node after ssh to the bastion `ssh -i <private key file> ec2-user@<bastion DNS/IP>`
```bash
$ Node1
```

If you wish to run `geth attach` tunneling via SSH to Node1: `ssh -t -i <private key file> ec2-user@<bastion DNS/IP> Node1`

`ethstats` is also available at `http://<bastion DNS/IP>:3000`

## Logging

* Logs are available in CloudWatch Group `/ecs/quorum/**`
* CPU and Memory utilization metrics are also available in CloudWatch

## Cleaning up

```
terraform destroy
```