# 🚀 Lawyered-in Infrastructure Project

This repository contains the full Terraform-managed infrastructure for the Lawyered-in microservices ecosystem on AWS.

## 🏗️ Architecture Overview

The infrastructure is built with high availability and scalability in mind:
- **VPC Design**: Multi-AZ spanning 3 Availability Zones with Public, Private (App), and Database subnet tiers.
- **EKS Cluster**: Managed Kubernetes cluster (`eks-cluster-np`) with automated node scaling.
- **Database**: Aurora MySQL Serverless v2 cluster for high-performance data storage.
- **CI/CD**: Automated pipelines for 7 microservices using AWS CodePipeline and ECR.

## 🛠️ Infrastructure Components

### 1. EKS Addons & Scaling
- **Cluster Autoscaler**: Automatically manages the size of the node groups based on pod demand (IRSA enabled).
- **AWS Load Balancer Controller**: Manages ALBs and NLBs via Kubernetes Ingress/Service objects.
- **Metrics Server**: Provides resource metrics for HPA and cluster monitoring.

### 2. GitOps with Argo CD
- Fully automated application delivery via Argo CD.
- **Ingress**: Exposed via a dedicated high-availability ALB (`lawyered-ingress-alb`) distributed across all 3 public subnets.

### 3. CI/CD Suite
- Reusable `codepipeline` module.
- Integration with GitHub via **AWS CodeStar Connections**.
- **ECR Repositories**: 7 dedicated repositories with lifecycle policies (retaining 3 most recent images).
- **Base Image Mirroring**: Uses ECR Public Gallery to bypass Docker Hub rate limits.

---

## 🚀 How to Spin Up the Infrastructure

### Step 1: Initialize
```powershell
# Navigate to the templates directory
cd resources/templates

# Initialize Terraform and providers
terraform init
```

### Step 2: Import GitHub Connection
*Crucial step to sync manually created AWS connections.*
```powershell
terraform import aws_codeconnections_connection.github <CONNECTION_ARN>
```

### Step 3: Deployment
```powershell
# Validate the configuration
terraform validate

# Review the plan
terraform plan

# Apply the infrastructure
terraform apply -auto-approve
```

## 🧩 Module Inventory
- `modules/vpc`: Custom VPC and subnet management.
- `modules/eks`: Cluster and node group provisioning.
- `modules/ecr`: ECR repositories and lifecycle policies.
- `modules/codepipeline`: Automated build and push logic for microservices.
- `modules/aurora`: Managed Aurora MySQL cluster.
- `modules/argocd`: GitOps platform installation.

---
*Created and maintained by the Lawyered-in Platform Engineering team.*
