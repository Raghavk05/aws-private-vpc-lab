# terraform-aws-private-vpc

Terraform that provisions an AWS VPC with a private EC2 instance that has
outbound internet access and **no public IP address**. Egress runs through a
NAT gateway in a public subnet, which hands off to an internet gateway.
Shell access is via SSM Session Manager, so there is no bastion host, no key
pair, and no inbound security group rule.

Built as a hands-on exercise in infrastructure as code. Small enough to read
in one sitting, structured the same way a production module would be.

## Architecture

```
Internet
   |
 [ IGW ]                         1:1 NAT, needs a public IP
   |
 [ Public subnet 10.0.1.0/24 ]
   |  [ NAT Gateway + Elastic IP ]   many:1 NAT for private resources
   |
 [ Private subnet 10.0.2.0/24 ]
      [ EC2, private IP only, zero ingress rules ]
```

Full walkthrough of the traffic flow: [docs/architecture.md](docs/architecture.md)

## What gets created

| Resource | Purpose |
|---|---|
| VPC | 10.0.0.0/16 with DNS support and hostnames enabled |
| Public subnet | Hosts the NAT gateway |
| Private subnet | Hosts the workload instance |
| Internet gateway | Egress path for the public subnet |
| Elastic IP + NAT gateway | Outbound-only path for the private subnet |
| Two route tables | Public to IGW, private to NAT |
| Security group | Zero ingress rules, all egress allowed |
| IAM role + instance profile | `AmazonSSMManagedInstanceCore` for Session Manager |
| EC2 instance | Amazon Linux 2023, IMDSv2 required, encrypted gp3 root volume |

## Cost warning

The NAT gateway has no free tier on any account type. It bills from the first
hour at roughly $0.045 per gateway-hour (about $32 per month in us-east-1)
plus $0.045 per GB processed. Everything else in this stack is free-tier
eligible.

Run `terraform destroy` when you are finished with a session and the cost
stays in cents. Or set `enable_nat_gateway = false` to build the network with
no egress path and no charge.

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI v2, configured with credentials (`aws configure`)
- Session Manager plugin for the AWS CLI, if you want shell access

## Usage

```bash
git clone https://github.com/<your-username>/terraform-aws-private-vpc.git
cd terraform-aws-private-vpc

cp terraform.tfvars.example terraform.tfvars   # edit if you want

terraform init
terraform plan
terraform apply
```

Open a shell on the private instance:

```bash
aws ssm start-session --target $(terraform output -raw instance_id)
```

Confirm the instance really has no public IP but can still reach out:

```bash
# inside the session
curl -s https://checkip.amazonaws.com     # returns the NAT gateway's Elastic IP
sudo dnf update -y                        # works, proving outbound egress
```

Tear it down:

```bash
terraform destroy
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `aws_region` | Region to deploy into | `string` | `us-east-1` |
| `project_name` | Name prefix for all resources | `string` | `private-vpc-lab` |
| `environment` | Environment tag value | `string` | `dev` |
| `vpc_cidr` | VPC CIDR block | `string` | `10.0.0.0/16` |
| `public_subnet_cidr` | Public subnet CIDR | `string` | `10.0.1.0/24` |
| `private_subnet_cidr` | Private subnet CIDR | `string` | `10.0.2.0/24` |
| `instance_type` | EC2 instance type | `string` | `t3.micro` |
| `enable_nat_gateway` | Create the NAT gateway and private default route | `bool` | `true` |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `private_subnet_id` | ID of the private subnet |
| `instance_id` | ID of the private EC2 instance |
| `instance_private_ip` | Private IP of the instance |
| `nat_gateway_public_ip` | Address the instance appears as on the internet |
| `session_manager_command` | Ready-to-run command to open a shell |

## Repo layout

```
.
├── versions.tf              # Terraform and provider version constraints
├── providers.tf             # AWS provider and default tags
├── variables.tf             # Input variables
├── network.tf               # VPC, subnets, IGW, NAT, route tables
├── compute.tf               # AMI lookup, security group, IAM, EC2
├── outputs.tf               # Outputs
├── terraform.tfvars.example # Copy to terraform.tfvars
├── .github/workflows/
│   └── terraform.yml        # fmt, init, validate on push and PR
└── docs/
    └── architecture.md      # Traffic flow, cost model, design notes
```

## Roadmap

- [ ] Containerize a sample workload and run it on the instance with Docker
- [ ] Multi-AZ: `for_each` over availability zones for subnets and NAT
- [ ] Remote state in S3 with DynamoDB locking
- [ ] OIDC authentication for the GitHub Actions pipeline instead of long-lived keys
- [ ] `terraform plan` output posted as a PR comment

## License

MIT
