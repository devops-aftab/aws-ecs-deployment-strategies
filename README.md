# AWS ECS Deployment Strategies Portfolio

Welcome to my AWS ECS (Elastic Container Service) reference architecture portfolio. This repository contains end-to-end, fully automated infrastructure configurations built with **Terraform** to demonstrate different advanced production deployment methodologies on AWS.

Each strategy is completely isolated, self-contained, and engineered adhering to cloud architecture best practices (including high availability, security isolation, and strict principle of least privilege).

---

## Repository Structure

The project is divided into two distinct execution strategies, allowing you to compare host-managed vs. serverless container orchestration side-by-side:

### [01-ec2-backed-cluster](./01-ec2-backed-cluster)
* **Compute Type:** Managed EC2 Host Fleet via an Auto Scaling Group.
* **Core Concepts:** 
  * Fetching dynamic, official AWS ECS-optimized AMIs via SSM Parameter Store.
  * Custom network routing across a Multi-AZ public VPC.
  * **Dynamic Host Port Mapping (`hostPort = 0`)** with Docker bridge networking to optimize container placement density.
  * Application Load Balancer (ALB) integration for automatic traffic routing to ephemeral host ports.
* **Best Used For:** Workloads requiring full control over underlying EC2 host instances, custom OS-level daemons, or strict optimization of compute costs via container density.

### [02-fargate-backed-cluster](./02-fargate-backed-cluster)
* **Compute Type:** AWS Fargate (Serverless Container Platform).
* **Core Concepts:**
  * Zero-infrastructure host provisioning or scaling management.
  * Strict network-level container isolation (typically utilizing `awsvpc` network mode).
  * Direct task-level security group assignments.
* **Best Used For:** Modern cloud-native microservices where team focus must remain purely on application business logic, offloading host provisioning, patching, and OS scaling entirely to AWS.

---

## 🛠️ General Prerequisites

To run any of the deployment blueprints in this repository, you will need:
* **Terraform** (`>= 1.0.0`) installed locally.
* **AWS CLI** configured with appropriate administrative credentials.
* An active AWS Account.

To deploy either infrastructure stack, change directories into the target folder and run the standard Terraform lifecycle workflow:
```bash
cd 01-ec2-backed-cluster   # Or 02-fargate-backed-cluster
terraform init
terraform plan
terraform apply