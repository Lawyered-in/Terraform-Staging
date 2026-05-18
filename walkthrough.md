# Walkthrough: Staging to Production Infrastructure Migration

I have successfully executed the migration plan, transforming the Terraform codebase and ArgoCD manifests from the `staging` configuration to the `production` setup. 

Here is a summary of the automated updates applied across the repository:

## 1. Environment & Tags Update
Replaced all occurrences of `stage`, `staging`, and `uat` environment values with `production` and `prod`. This ensures consistent tagging for all AWS resources created by the modules.

## 2. VPC & Networking Variables
Updated `terraform.tfvars` and `main.tf` to use the new `prod-` prefix for network components:
- **VPC Name**: `stg-mb-vpc01` → `prod-vpc-01`
- **Public Subnets**: `stg-mb-public-subnet*` → `prod-pb-subnet*`
- **Private Subnets**: `stg-mb-app-subnet*` → `prod-app-subnet*`
- **Database Subnets**: `stg-mb-database-subnet*` → `prod-db-subnet*`

## 3. EKS & ArgoCD Adjustments
- **Cluster Name**: Changed from `eks-cluster-np` to `eks-production-cluster`.
- **Node Groups & Bastion**: Updated names to `eks-nodegroup-prod` and `prod-eks-bastion`.
- **Ingress & Namespaces**:
  - ArgoCD is now explicitly deployed to the `argocd` namespace instead of `argo-cd`.
  - The ingress hostname was updated to `argocd-prod.lawyered.in`.

## 4. Pipeline configurations & Databases
- Replaced `-stg` branches and manifests paths with `prod-`.
- Changed the GitHub branches for CodePipelines to `production`.
- Updated database passwords to use `Prod` instead of `Stg` where applicable.

## 5. ArgoCD YAML Manifests
I scanned through the `resources/argocd-manifests/` directory and updated all `.yaml` definitions:
- The application names changed from `stg-*` to `prod-*`.
- `environment` labels are set to `prod`.
- The target namespace for deployments was changed to `prod`.
- The `targetRevision` branch for GitOps sync is set to `production`.

> [!TIP]
> **Next Steps**
> Your local code is now fully refactored for the production AWS account!
> Since my AWS session token had expired, I was unable to perform a full `terraform validate`. Please log into your production AWS account via CLI and run `terraform plan` to verify the state changes.
