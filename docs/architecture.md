# Architecture

## Diagram

```
                            Internet
                                |
                                |
                    +-----------+-----------+
                    |   Internet Gateway    |   1:1 NAT for resources
                    |        (IGW)          |   that HAVE a public IP
                    +-----------+-----------+
                                |
  VPC 10.0.0.0/16               |
  +-----------------------------+-------------------------------+
  |                             |                               |
  |   Public subnet 10.0.1.0/24 |                               |
  |   +-------------------------+---------------------------+   |
  |   |                                                     |   |
  |   |   +---------------------------------------------+   |   |
  |   |   |  NAT Gateway  (Elastic IP)                  |   |   |
  |   |   |  many:1 NAT for the private subnet          |   |   |
  |   |   +----------------------+----------------------+   |   |
  |   |                          ^                          |   |
  |   +--------------------------|--------------------------+   |
  |                              |                              |
  |                              | 0.0.0.0/0 route              |
  |                              |                              |
  |   Private subnet 10.0.2.0/24 |                              |
  |   +--------------------------|--------------------------+   |
  |   |                          |                          |   |
  |   |   +----------------------+----------------------+   |   |
  |   |   |  EC2 instance                               |   |   |
  |   |   |  private IP only, no public IP              |   |   |
  |   |   |  SG: zero ingress rules, all egress         |   |   |
  |   |   |  IAM: AmazonSSMManagedInstanceCore          |   |   |
  |   |   +---------------------------------------------+   |   |
  |   |                                                     |   |
  |   +-----------------------------------------------------+   |
  |                                                             |
  +-------------------------------------------------------------+
```

## Why the NAT gateway is required

A common mistake is assuming an internet gateway alone is enough for a
private instance. It is not.

An internet gateway enables resources in your public subnets to connect to
the internet only if the resource has a public IPv4 or IPv6 address. The IGW
logically provides a one-to-one NAT on behalf of the instance: when traffic
leaves the subnet, the reply address field is rewritten to the instance's
public or Elastic IP rather than its private IP.

No public IP means the IGW has nothing to translate to, so return traffic has
nowhere to go. The connection fails.

The NAT gateway solves this. It sits in the public subnet, holds its own
Elastic IP, and translates traffic from many private instances onto that one
address. Private instances get outbound access while the internet cannot
initiate an inbound connection to them.

Broken into steps, an outbound request from the private instance:

1. Instance sends a packet to 0.0.0.0/0
2. Private route table matches, target is the NAT gateway
3. NAT gateway rewrites the source to its Elastic IP and tracks the flow
4. Public route table matches 0.0.0.0/0, target is the IGW
5. IGW forwards to the internet
6. Response returns to the Elastic IP, NAT gateway maps it back to the
   instance's private IP using its connection table

## Access without a bastion

There is no key pair and no SSH ingress rule in this build. Access is through
AWS Systems Manager Session Manager, which the SSM agent initiates outbound
over the NAT path. That means shell access with zero open inbound ports.

```bash
aws ssm start-session --target <instance-id> --region us-east-1
```

## Cost model

The NAT gateway is the only meaningful cost here and it has no free tier on
any account type. It bills from the moment it is created at roughly
$0.045 per gateway-hour (about $32 per month in us-east-1) plus $0.045 per GB
processed, and standard data transfer charges apply on top.

Two ways to control this:

| Approach | Cost | Trade-off |
|---|---|---|
| `apply`, test, `destroy` same session | Cents per session | Must rebuild each time, which is the point of IaC |
| `enable_nat_gateway = false` | $0 | Instance has no internet path, and no Session Manager access |
| NAT instance on a small EC2 | Cheaper, free-tier eligible compute | Manual setup, single point of failure, you manage patching |

The everything-on-demand approach is the one this repo is built around.

## What this maps to in production

The same file layout scales without a rewrite. A production three-tier VPC
across three availability zones changes the variables and adds a `for_each`
over a list of AZs. The resource definitions themselves stay the same.
