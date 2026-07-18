# AWS ECS Cluster (EC2-Backed) with Terraform

This repository provisions a highly available, load-balanced Amazon ECS (Elastic Container Service) cluster backed by an Auto Scaling Group of EC2 host instances[cite: 1]. The infrastructure is built fully from scratch using infrastructure as code (IaC) with Terraform[cite: 1, 3].

##  Architecture Overview

The configuration deploys a complete, secure infrastructure stack that includes:

1. **Networking**: A custom VPC across two Availability Zones with Public Subnets, an Internet Gateway, and public routing tables[cite: 1].
2. **Security**: Separated Security Groups ensuring that the public internet can only access the Application Load Balancer (ALB) on port 80[cite: 1], and the EC2 instances only accept traffic routed directly from the ALB[cite: 1].
3. **Load Balancing**: An Application Load Balancer configured with dynamic target group tracking to handle inbound web traffic[cite: 1].
4. **Compute & Auto Scaling**: An Auto Scaling Group (ASG) utilizing a Launch Template that dynamically fetches the latest official AWS ECS-optimized Amazon Linux 2 AMI[cite: 1].
5. **Container Orchestration**: An ECS Cluster orchestrating an NGINX demo application utilizing **Dynamic Host Port Mapping** and Docker `bridge` networking[cite: 1].

---

##  Key Design Patterns Demonstrated

### Dynamic Host Port Mapping
Instead of binding container applications to a hardcoded host port (which prevents multiple containers of the same type from running on a single instance), this configuration sets `hostPort = 0`[cite: 1]. This instructs the ECS container agent and Docker to allocate a random ephemeral port on the EC2 host[cite: 1]. The ECS Service automatically registers these dynamic ports with the ALB Target Group[cite: 1], allowing multiple container tasks to run smoothly across fewer host machines without resource collisions.

### Secure Principle of Least Privilege
* **ECS Instance Profile**: Grants the underlying EC2 hosts permissions to communicate with the ECS control plane, register into the cluster, and pull container configurations[cite: 1].
* **ECS Task Execution Role**: Dedicated role allowing the core ECS container engine to pull application images and push logging output[cite: 1].

### Zero-Downtime Launch Templates
The EC2 launch configuration utilizes a `name_prefix` and a `create_before_destroy` lifecycle policy[cite: 1]. This ensures that if the host layout or configuration changes, Terraform spins up the new configuration first before tearing down the old one, preventing AWS `EntityAlreadyExists` dependency blocks or cluster registration locks[cite: 1].

---

## File Structure

* `main.tf` - Core infrastructure: VPC, Security Groups, ALB, ASG, and ECS configuration[cite: 1].
* `provider.tf` - Defines the AWS provider version limits and deployment region[cite: 3].
* `variables.tf` - Exposed variables for cluster customization (e.g., instance types, CIDR blocks)[cite: 5].
* `outputs.tf` - Outputs the final public-facing endpoint of the application load balancer.
* `userdata.sh` - Standard shell script mapping the EC2 host node to the specific target ECS cluster upon boot[cite: 1, 4].

---

## Getting Started

### Prerequisites
* [Terraform](https://www.terraform.io/downloads.html) (`>= 1.0.0`)[cite: 3]
* Configured AWS CLI credentials with appropriate permissions

### Deployment Steps

1. **Initialize the workspace**
   ```bash
   terraform init