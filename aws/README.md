## Quorum Cloud: AWS

Deploy a Quorum Network in AWS using [Terraform](https://terraform.io).

> AWS Fargate is only available in certain regions, see [AWS Region Table](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) for more details.

> AWS Fargate has default limits which might impact the provisioning, see [Amazon ECS Service Limits](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service_limits.html) for more details.

## What will this create?
This will create a Quorum network (with 7 nodes by default) using AWS ECS Fargate, S3 and an EC2.  The network can be configured to use either Raft or Istanbul consensus and either Tessera or Constellation privacy managers. 

### Overview

```
                   +----- Public Subnet -----+       +----- Private Subnet(s) ---+
                   |                         |       |                           |
Internet <--- [NAT Gateway]     [Bastion] ---------->|  [ECS] [ECS] [ECS] ....   |
                 ^ |                         |       |                           |
                 | +-------------------------+       +-------------.-------------+
                 |                                                 |
                 +------------------- Routable --------------------+ 
```

#### Node containers (ECS Fargate)

Each Quorum/privacy manager node pair is run in a separate AWS ECS (Elastic Container Service) Service.

Each ECS Service contains the following Tasks to bootstrap and start the node pair:
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
  * `{tx-privacy-engine}-run`: start the privacy manager
  * `quorum-run`: start Quorum

#### Bastion node

The Bastion is publically accessible and enables `geth attach` to each Quorum node in the private subnet.  Additionally it exposes `ethstats` to more easily view activity on the network. 

## Prerequisites
> Terraform v0.12 introduced significant configuration language changes and so is not currently supported
* Install Terraform v0.11
    * From [HashiCorp website](https://www.terraform.io/downloads.html)
    * MacOS: `brew install terraform@0.11`
* Install AWS CLI
    * MacOS: https://docs.aws.amazon.com/cli/latest/userguide/install-macos.html
    * Linux: https://docs.aws.amazon.com/cli/latest/userguide/install-linux.html
* Configure AWS CLI 
    ```bash
    aws configure
    ```
    Follow the prompts to provide credentials and preferences for the AWS CLI
* Create an AWS VPC with Subnets if one does not already exist
    * Create a VPC with a public and private subnet and corresponding networking as visualised in the above diagram
    * For more help see the [AWS documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario2.html) 

## Getting Started

### Step 1: Prepare environment

This will create an AWS environment with the resources required for deployment. 

This has to be run once **per region and per AWS Account**.

```bash
aws cloudformation create-stack --stack-name quorum-prepare-environment --template-body file://./quorum-prepare-environment.cfn.yml
```
This will create a CloudFormation stack containing the following AWS resources:
* An S3 bucket to store Terraform state with default server-side-encryption enabled
* A KMS Key to encrypt objects stored in the above S3 bucket

These resources are exposed to CloudFormation Exports which will be used in subsequent steps.

### Step 2: Initialize Terraform

This will read from CloudFormation Exports to generate two files (`terraform.auto.backend_config` and `terraform.auto.tfvars`) that are used in later steps.

```bash
cd /path/to/quorum-cloud/aws/templates/_terraform_init
terraform init
terraform apply -var network_name=dev -var region=us-east-1 -auto-approve
```

Replace `<region>` with the AWS region being used.

If `network_name` is not provided, a random name will be generated.

### Step 3: Prepare for deployment

```bash
cd /path/to/quorum-cloud/aws/templates/
touch terraform.tfvars
```

Populate `terraform.tfvars` with the below template, replacing the subnet IDs with the corresponding IDs for the VPC subnets being used.

```toml
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

 access_bastion_cidr_blocks = [
   "190.190.190.190/32",
 ]
```

* `subnet_ids`: ECS will provision containers in these subnets. The subnets must be routable to the Internet (either because they are public subnets by default or because they are private subnets routed via NAT Gateway)
* `is_igw_subnets`: `true` if the above `subnet_ids` are attached with Internet Gateway, `false` otherwise
* `bastion_public_subnet_id`: where Bastion node is provisioned. This must be a public subnet
* `consensus_mechanism`: the default value is `raft`
* `tx_privacy_engine`: the default value is `tessera`
* `access_bastion_cidr_blocks`: In order to access the Bastion node from a particular IP/set of IPs the corresponding CIDR blocks must be set

**Note:** [`variables.tf`](templates/variables.tf) contains full options to configure the network

### Step 4: Deploy the network

```bash
cd /path/to/quorum-cloud/aws/templates/
terraform init -backend-config=terraform.auto.backend_config -reconfigure
terraform apply
```

Terraform will prompt to accept the proposed infrastructure changes.  After the changes are accepted and the deployment is complete, information about the created network will be output.  

An example of the output is:
```bash
Quorum Docker Image         = quorumengineering/quorum:latest
Privacy Engine Docker Image = quorumengineering/tessera:latest
Number of Quorum Nodes      = 7
ECS Task Revision           = 1
CloudWatch Log Group        = /ecs/quorum/dev

bastion_host_dns = ec2-5-1-112-217.us-east-1.compute.amazonaws.com
bastion_host_ip = 5.1.112.217
bucket_name = eu-west-2-ecs-dev-6dj72u9s6335853j
chain_id = 4021
ecs_cluster_name = quorum-network-dev
network_name = dev
private_key_file = /path/to/quorum-cloud/aws/templates/quorum-dev.pem
```

### Step 5: Examining the network

Noting the `bastion_host_ip`/`bastion_host_dns` and `private_key_file` from the output of the previous step, run the following to SSH in to the Bastion node:

```bash
chmod 600 <private-key-file>
ssh -i <private-key-file> ec2-user@<bastion-DNS/IP>
```

From the Bastion node it is possible to `geth attach` to any of the Quorum nodes with a simple alias:
```bash
[bastion-node]$ Node1
```

It is also possible to `geth attach` to any of the nodes without having to first explicitly SSH into the Bastion node:

```bash
ssh -t -i <private-key-file> ec2-user@<bastion-DNS/IP> Node1
```

`ethstats` is available at `http://<bastion-DNS/IP>:3000`

### Step 6: Cleaning up
```bash
cd /path/to/quorum-cloud/aws/templates/
terraform destroy
```

Note: In case `terraform destroy` is unable to detroy all the AWS resources, run [`utils/cleanup.sh`](utils/cleanup) (which uses [aws-nuke](https://github.com/rebuy-de/aws-nuke)) to perform full clean up

## Logging

* The logs for each running node and bootstrap tasks are available in CloudWatch Group `/ecs/quorum/**`
* CPU and Memory utilization metrics are also available in CloudWatch
