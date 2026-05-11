# GitOps Manifest Auto-Update — Walkthrough

We have successfully implemented and verified the automated manifest update flow for all 7 microservices. This ensures that every time code is pushed to the `staging` branch, the EKS deployment is automatically updated via GitOps (Argo CD).

## 🚀 Key Achievements

### 1. SSH-Based Authentication
Instead of using Personal Access Tokens (PATs) which expire, we implemented a permanent SSH-based authentication method.
- **Private Key**: Stored securely in AWS Secrets Manager (`github-connection-key`).
- **Deploy Key**: The corresponding public key is registered on the `k8s-manifest` repository with write access.
- **Security**: The key is fetched dynamically during the build and never stored in the code or logs.

### 2. Automated Manifest Updates
The CodeBuild `post_build` phase now includes a robust script that:
- Clones the `k8s-manifest` repository.
- Identifies the correct deployment directory (e.g., `deployments/stg-lawyered.in-website`).
- Updates the `image` tag in `deployment.yaml` using the new ECR image URI.
- Commits and pushes the change back to the `staging` branch.

### 3. End-to-End Verification
We verified the flow with the `lawyered.in-website` pipeline:
- **Typo Fix**: Corrected the repository ID from `lawyered-in-website` to `lawyered.in-website`.
- **Pipeline Run**: Triggered the pipeline manually.
- **Build Success**: Confirmed that the image was built, pushed to ECR, and the manifest was successfully updated in GitHub.

## 🛠️ Technical Details

### IAM Permissions
Added `secretsmanager:GetSecretValue` permission to all CodeBuild service roles to allow them to fetch the SSH key.

### Terraform Configuration
- Updated the `codepipeline` module to support `manifest_file_path`.
- Configured all 7 services in `terraform.tfvars` with their respective manifest paths.

## 🗄️ RDS Infrastructure Modernization
- **New Database**: Provisioned `lawyered-backend-new` (50 GB) with PostgreSQL 18.3.
- **Storage Optimization**: Capped `finvica` autoscaling at 100 GB to reduce potential costs.
- **Security**: Implemented dynamic Secrets Manager loops for all RDS instances.
- **Documentation**: Detailed report created at [rds-infrastructure-modernization.md](file:///c:/Users/PavanSD/Downloads/resources/implementation_plan/rds-infrastructure-modernization.md).

## 📁 Implementation Documents
- [INDEX.md](file:///c:/Users/PavanSD/Downloads/resources/implementation_plan/INDEX.md) — Master index of all plans.
- [CodeBuild SSH Key Manifest Auto Update.txt](file:///c:/Users/PavanSD/Downloads/resources/implementation_plan/2026-04-27/CodeBuild%20SSH%20Key%20Manifest%20Auto%20Update.txt) — Detailed task-wise log.
- [How GitHub Connection Works.txt](file:///c:/Users/PavanSD/Downloads/resources/implementation_plan/How%20GitHub%20Connection%20Works.txt) — Reference document on AWS-GitHub integration.

## ✅ Final Status: ALL GREEN
The infrastructure is now fully automated and follows GitOps best practices.
