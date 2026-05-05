# Implementation Plan: GitOps Manifest Updates via CodeBuild

This plan automates the update of image tags in a GitOps manifest repository (`Lawyered-in/k8s-manifest`) after a successful build and push to AWS ECR.

## User Review Required

> [!IMPORTANT]
> **GitHub Token Source**: The build process requires a GitHub Personal Access Token (PAT) to push changes to the manifest repository. I have defaulted the secret name to `lawyered/github/token`. You must ensure this secret exists in AWS Secrets Manager in the `ap-south-1` region.

> [!WARNING]
> **Repository Access**: Ensure the PAT used has `repo` scope permissions for the `Lawyered-in/k8s-manifest` repository.

## Proposed Changes

---

### [Component] CodePipeline Module

#### [MODIFY] [variables.tf](file:///c:/Users/PavanSD/Downloads/resources/resources/modules/codepipeline/variables.tf)
Add supporting variables for manifest tracking:
- `manifest_repository_id`: The target repository for manifests.
- `manifest_file_path`: Path to the service's `deployment.yaml`.
- `github_token_secret_name`: Name of the secret containing the PAT.

#### [MODIFY] [main.tf](file:///c:/Users/PavanSD/Downloads/resources/resources/modules/codepipeline/main.tf)
1.  **IAM Policy Update**: Add `secretsmanager:GetSecretValue` permission to the `aws_iam_role_policy.build`.
2.  **Buildspec Update**:
    -   Fetch secret in `pre_build`.
    -   Clone and update manifest in `post_build`.
    -   Use `sed` for robust image replacement based on repository name.

---

### [Component] Root Templates

#### [MODIFY] [variables.tf](file:///c:/Users/PavanSD/Downloads/resources/resources/templates/variables.tf)
Update the `codepipelines` map object definition to include `manifest_file_path`.

#### [MODIFY] [main.tf](file:///c:/Users/PavanSD/Downloads/resources/resources/templates/main.tf)
Pass the `manifest_file_path` from the `var.codepipelines` map to the `codepipeline` module.

#### [MODIFY] [terraform.tfvars](file:///c:/Users/PavanSD/Downloads/resources/resources/templates/terraform.tfvars)
Provide the correct manifest file paths for each service.

## Open Questions

- Should the update logic strictly look for `:latest` or replace any existing tag? (Currently planning to replace any existing tag for the specific image URL).
- Is `staging` the only branch we target for manifest updates, or should this be configurable per pipeline? (Defaulting to `staging`).

## Verification Plan

### Automated Tests
- `terraform plan`: Ensure no circular dependencies or syntax errors.
- **Trial Run**: Trigger a build for one service (e.g., `qr-api`) and inspect CodeBuild "Post Build" logs.

### Manual Verification
1.  Verify the secret `lawyered/github/token` exists in AWS Console.
2.  Check the `k8s-manifest` GitHub repo for a new commit after the build finishes.
3.  Check the `deployment.yaml` file to ensure the `image:` line reflects the new commit hash.
