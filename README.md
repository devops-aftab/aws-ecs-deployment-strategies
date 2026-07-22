# AWS ECS Deployment Strategies Portfolio

Welcome to my AWS ECS (Elastic Container Service) reference architecture portfolio. This repository contains end-to-end, fully automated infrastructure configurations built with **Terraform** to demonstrate different production deployment methodologies on AWS.

This project contrasts **EC2-Backed (IaaS)** versus **Fargate (Serverless)** container deployment strategies, showcasing production-ready network design, multi-AZ high availability, Application Load Balancers (ALB), and automated target group health tracking.

---

## Architectural Comparison Matrix

| Feature / Metric | Strategy 01: EC2-Backed Cluster | Strategy 02: Fargate (Serverless) Cluster |
| :--- | :--- | :--- |
| **Compute Management** | Manual EC2 Instance & Auto Scaling Group management | Fully managed by AWS (Serverless) |
| **Infrastructure Overhead**| High (OS patching, AMI updates, capacity planning) | Zero (AWS handles host maintenance) |
| **Scaling & Boot Time** | Slower (requires launching EC2 instances first) | Fast (provisions container tasks directly) |
| **Cost Model** | Pay for running EC2 instances (regardless of task load) | Pay strictly per vCPU and Memory consumed per second |
| **Isolation & Security** | Shared EC2 host kernel across containers | Hypervisor-level boundary per task |
| **Ideal Use Case** | Predictable workloads, custom EC2 requirements, cost optimization at scale | Variable workloads, rapid scaling, microservices, minimal ops |

---

## Repository Structure

```text
aws-ecs-deployment-strategies/
├── 01-ec2-backed-cluster/        # IaC for ECS on EC2 (ASG, Capacity Providers, Launch Templates)
├── 02-fargate-backed-cluster/    # IaC for ECS on Fargate (Serverless execution, Task Definitions)
└── images/                       # Architectural diagrams & deployment verification proofs
    ├── infra-diagrams/
    └── deployment-proofs/
        ├── 01-ec2-backed/
        └── 02-fargate-backed/
```

### Deployment Strategy Highlights

#### [01-ec2-backed-cluster](./01-ec2-backed-cluster)
* **Compute Type:** Managed EC2 Host Fleet via an Auto Scaling Group.
* **Core Concepts:** 
  * Fetching dynamic, official AWS ECS-optimized AMIs via SSM Parameter Store.
  * Custom network routing across a Multi-AZ public VPC.
  * **Dynamic Host Port Mapping (`hostPort = 0`)** with Docker bridge networking to optimize container placement density.
  * Application Load Balancer (ALB) integration for automatic traffic routing to ephemeral host ports.
* **Best Used For:** Workloads requiring full control over underlying EC2 host instances, custom OS-level daemons, or strict optimization of compute costs via container density.

#### [02-fargate-backed-cluster](./02-fargate-backed-cluster)
* **Compute Type:** AWS Fargate (Serverless Container Platform).
* **Core Concepts:**
  * Zero-infrastructure host provisioning or scaling management.
  * Strict network-level container isolation (`awsvpc` network mode).
  * Direct task-level security group assignments.
* **Best Used For:** Modern cloud-native microservices where team focus remains purely on application business logic, offloading host provisioning, patching, and OS scaling entirely to AWS.

---

## Prerequisites & Quick Start

### Prerequisites
* **Terraform** (`>= 1.0.0`) installed locally.
* **AWS CLI** configured with administrative credentials.
* An active AWS Account.

> **Production Architecture Note:** This lab utilizes local Terraform state (`terraform.tfstate`) for isolated local demonstration. In a production environment, remote state management should be configured using an **AWS S3 Backend** paired with a **DynamoDB table** for state locking and concurrency protection.

### Deployment Workflow

To deploy either infrastructure stack, change directories into the target folder and execute standard Terraform lifecycle commands:

```bash
# Navigate into desired strategy
cd 01-ec2-backed-cluster   # Or cd 02-fargate-backed-cluster

# Initialize provider plugins
terraform init

# Review execution plan
terraform plan

# Apply infrastructure provisioning
terraform apply
```

To clean up resources and prevent unexpected AWS charges:

```bash
terraform destroy
```