# Implementation Plan - Deploying `subscriber-fe` and `lawyered-be`

This plan outlines the steps to deploy two new applications, `subscriber-fe` and `lawyered-be`, following the existing infrastructure patterns.

## User Review Required

> [!IMPORTANT]
> - **GitHub Connection**: I will use the existing `lawyered-github-repository` connection (`arn:aws:codeconnections:ap-south-1:344367180480:connection/57bb41a6-94e5-4be9-9364-73bc9da899d3`) for both pipelines as requested.
> - **Namespaces**: Both applications will be deployed to the `stg` namespace in Kubernetes via ArgoCD.

## Proposed Changes

### Infrastructure Configuration

#### [MODIFY] [terraform.tfvars](file:///c:/Users/PavanSD/Downloads/resources/resources/templates/terraform.tfvars)
- Add ECR repository definitions for `subscriber-fe` and `lawyered-be`.
- Add CodePipeline definitions for both applications, specifying:
  - Repository ID (e.g., `Lawyered-in/subscriber-fe`)
  - Branch (`staging`)
  - ECR key reference
  - Manifest file path in the `k8s-manifest` repository.
  - Shared GitHub connection ARN.

### ArgoCD Manifests

#### [NEW] [subscriber-fe.yaml](file:///c:/Users/PavanSD/Downloads/resources/resources/argocd-manifests/subscriber-fe.yaml)
- Define the ArgoCD Application for `subscriber-fe`.
- Source: `git@github.com:Lawyered-in/k8s-manifest.git`
- Path: `deployments/stg-subscriber-fe`
- Destination Namespace: `stg`

#### [NEW] [lawyered-be.yaml](file:///c:/Users/PavanSD/Downloads/resources/resources/argocd-manifests/lawyered-be.yaml)
- Define the ArgoCD Application for `lawyered-be`.
- Source: `git@github.com:Lawyered-in/k8s-manifest.git`
- Path: `deployments/stg-lawyered-be`
- Destination Namespace: `stg`

## Verification Plan

### Automated Verification
- I will run `terraform plan` in the `resources/templates` directory (simulated or actual if possible) to ensure the configuration is valid.
- I will verify the syntax of the new YAML files.

### Manual Verification
- The user should run `terraform apply` to provision the AWS resources.
- Once applied, ArgoCD will automatically pick up the new manifests and deploy the applications to the EKS cluster.
- CodePipeline will trigger on the next push to the `staging` branch of the respective repositories.
