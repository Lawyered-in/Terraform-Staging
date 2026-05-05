# 🚀 Detailed CI/CD Flow — `lawyered-in-website` (Frontend)

> **Scope**: Developer pushes code to GitHub → Docker image built & pushed to ECR → K8s manifest updated → Argo CD deploys to EKS.

---

## 🧩 Systems Involved (Bird's Eye View)

```
GitHub (Lawyered-in/lawyered-in-website)
  → AWS CodePipeline (lawyered-in-website)
      → AWS CodeBuild (lawyered-in-website-build)
          → Amazon ECR (lawyered-in-website repo)
          → GitHub (Lawyered-in/k8s-manifest)  ← [PLANNED: manifest update]
              → Argo CD (stg-lawyered-in-website)
                  → EKS Cluster (eks-cluster-np)
                      → Namespace: stg
```

---

## 📋 STEP-BY-STEP FLOW

---

### STEP 1 — Developer Pushes Code to GitHub

| Item | Value |
|------|-------|
| **GitHub Repo** | `Lawyered-in/lawyered-in-website` |
| **Branch** | `staging` |
| **Action** | Developer runs `git push origin staging` |

**What happens next?**
AWS CodeStar Connection (configured in Terraform as `github_connection_arn`) detects this push via webhook and immediately triggers CodePipeline.

---

### STEP 2 — CodePipeline `Source` Stage Fires

**Pipeline name**: `lawyered-in-website`
**Terraform resource**: `aws_codepipeline.this` inside `modules/codepipeline/main.tf`
**Stage**: `Source`

```hcl
# modules/codepipeline/main.tf
stage {
  name = "Source"
  action {
    provider         = "CodeStarSourceConnection"
    FullRepositoryId = "Lawyered-in/lawyered-in-website"  # from terraform.tfvars
    BranchName       = "staging"                           # from terraform.tfvars
    output_artifacts = ["source_output"]                   # zipped source code
  }
}
```

**What happens?**
- CodePipeline downloads the full source code from `staging` branch
- Packages it into a ZIP and stores it in S3 bucket:
  `lawyered-in-website-artifacts-<AWS_ACCOUNT_ID>`
- This ZIP is called `source_output` — passed to the next stage

---

### STEP 3 — CodePipeline `Build` Stage Fires → CodeBuild Starts

**Pipeline stage**: `Build`
**CodeBuild project name**: `lawyered-in-website-build`
**Terraform resource**: `aws_codebuild_project.this` inside `modules/codepipeline/main.tf`

CodeBuild picks up the `source_output` ZIP, extracts it, and runs the buildspec.

---

### STEP 4 — CodeBuild `pre_build` Phase Runs

```bash
# 1. Login to ECR
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin \
    344367180480.dkr.ecr.ap-south-1.amazonaws.com

# 2. Pre-fetch base image from ECR Public (avoids Docker Hub rate limit 429)
#    prefetch_images = ["node:20-alpine"]  ← from terraform.tfvars
docker pull public.ecr.aws/docker/library/node:20-alpine
docker tag  public.ecr.aws/docker/library/node:20-alpine node:20-alpine

# 3. Set variables
REPOS_URL=344367180480.dkr.ecr.ap-south-1.amazonaws.com/lawyered-in-website
COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
# COMMIT_HASH = first 7 chars of git SHA, e.g.: "a3f92b1"
IMAGE_TAG=${COMMIT_HASH:=latest}
# IMAGE_TAG = "a3f92b1"
```

**Key variables set here:**

| Variable | Example Value |
|----------|--------------|
| `REPOS_URL` | `344367180480.dkr.ecr.ap-south-1.amazonaws.com/lawyered-in-website` |
| `COMMIT_HASH` | `a3f92b1` (first 7 chars of git SHA) |
| `IMAGE_TAG` | `a3f92b1` |

---

### STEP 5 — CodeBuild `build` Phase — Docker Image Built

```bash
# lawyered-in-website has NO build_args in terraform.tfvars
docker build -t $REPOS_URL:latest .
docker tag $REPOS_URL:latest $REPOS_URL:a3f92b1
```

> **Note**: `lawyered-in-website` has NO `build_args` in `terraform.tfvars`.
> Compare to `admin-lawyered-fe` which passes `VITE_API_URL`, `VITE_ENV`, etc.

---

### STEP 6 — CodeBuild `post_build` Phase — Push to ECR

```bash
# Push both tags to ECR
docker push $REPOS_URL:latest    # → ECR: lawyered-in-website:latest
docker push $REPOS_URL:a3f92b1  # → ECR: lawyered-in-website:a3f92b1

# Write artifact file
printf '[{"name":"container-name","imageUri":"%s"}]' \
  $REPOS_URL:a3f92b1 > imagedefinitions.json
```

**ECR Repository**: `lawyered-in-website`
**After push, ECR has:**
- `lawyered-in-website:latest`
- `lawyered-in-website:a3f92b1` ← stable, traceable tag

---

### STEP 7 — [PLANNED] `post_build` also Updates K8s Manifest

> ⚠️ **THIS IS WHAT WE ARE IMPLEMENTING.** Currently this step does NOT exist.

After the image is pushed, these commands will be ADDED to `post_build`:

```bash
# 1. Fetch GitHub PAT from AWS Secrets Manager
GITHUB_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id lawyered/github/token \
  --query SecretString --output text)

# 2. Clone the k8s-manifest repo (staging branch)
git clone https://x-access-token:${GITHUB_TOKEN}@github.com/Lawyered-in/k8s-manifest.git
cd k8s-manifest
git checkout staging

# 3. Update the image tag in deployment.yaml
#    File path: deployments/stg-lawyered-in-website/deployment.yaml
sed -i "s|image: .*lawyered-in-website:.*|image: $REPOS_URL:$IMAGE_TAG|g" \
  deployments/stg-lawyered-in-website/deployment.yaml

# 4. Commit and push
git config user.email "ci@lawyered.in"
git config user.name "CodeBuild CI"
git add deployments/stg-lawyered-in-website/deployment.yaml
git commit -m "ci: update lawyered-in-website to $IMAGE_TAG [skip ci]"
git push origin staging
```

**What gets updated in `k8s-manifest` repo?**

File: `Lawyered-in/k8s-manifest` → branch `staging`
Path: `deployments/stg-lawyered-in-website/deployment.yaml`

```yaml
# BEFORE:
image: 344367180480.dkr.ecr.ap-south-1.amazonaws.com/lawyered-in-website:b2e1c3f

# AFTER (auto-updated by CodeBuild):
image: 344367180480.dkr.ecr.ap-south-1.amazonaws.com/lawyered-in-website:a3f92b1
```

---

### STEP 8 — Argo CD Detects the Manifest Change

**Argo CD Application**: `stg-lawyered-in-website`
**Namespace**: `argo-cd`
**Config file**: `resources/argocd-manifests/lawyered-in-website.yaml`

```yaml
spec:
  source:
    repoURL: git@github.com:Lawyered-in/k8s-manifest.git
    targetRevision: staging                          # watching this branch
    path: deployments/stg-lawyered-in-website        # this folder
  syncPolicy:
    automated:
      prune: true
      selfHeal: true                                 # auto-syncs on any git change
```

Argo CD polls `k8s-manifest` → `staging` branch every ~3 mins (or via webhook).
It detects the new commit → sees the `image:` line changed → triggers a sync.

---

### STEP 9 — Argo CD Syncs → EKS Deploys New Pod

**EKS Cluster**: `eks-cluster-np`
**Namespace**: `stg`

Argo CD applies the updated `deployment.yaml` to EKS.
Kubernetes performs a rolling update:

```
Old Pod: lawyered-in-website:b2e1c3f  → Terminating
New Pod: lawyered-in-website:a3f92b1  → Running ✅
```

---

## 🗂️ Files That Will Be Updated (Implementation Plan)

| File | What Changes |
|------|-------------|
| `modules/codepipeline/variables.tf` | Add `manifest_file_path` and `github_token_secret_name` variables |
| `modules/codepipeline/main.tf` | Add IAM `secretsmanager:GetSecretValue` + `post_build` manifest update commands |
| `templates/variables.tf` | Add `manifest_file_path` to `codepipelines` variable object definition |
| `templates/main.tf` | Pass `manifest_file_path` into the codepipeline module call |
| `templates/terraform.tfvars` | Add `manifest_file_path` value for each of the 7 services |

---

## 📊 All 7 Services — Manifest Path Reference

| Pipeline Key (tfvars) | GitHub Source Repo | ECR Repo | K8s Manifest Path |
|---|---|---|---|
| `lawyered-in-website` | `Lawyered-in/lawyered-in-website` | `lawyered-in-website` | `deployments/stg-lawyered-in-website` |
| `admin-lawyered-fe` | `Lawyered-in/admin-lawyered-fe` | `admin-lawyered-fe` | `deployments/stg-admin-lawyered-fe` |
| `admin-lawyered` | `Lawyered-in/admin-lawyered` | `admin-lawyered` | `deployments/stg-admin-lawyered` |
| `partners-portal-fe` | `Lawyered-in/partners-portal-fe` | `partners-portal-fe` | `deployments/stg-partners-portal-fe` |
| `challanpay-fe-next` | `Lawyered-in/challanpay-fe-next` | `challanpay-fe-next` | `deployments/stg-challanpay-fe-next` |
| `api-challans` | `Lawyered-in/api-challans` | `api-challans` | `deployments/stg-api-challans` |
| `qr-api` | `Lawyered-in/qr-api` | `qr-api` | `deployments/stg-qr-api` |

---

## ✅ Pre-Requisites Before Coding Starts

1. **AWS Secrets Manager** — Create secret `lawyered/github/token` in `ap-south-1` with your GitHub PAT value
2. **GitHub PAT** — Must have `repo` scope for `Lawyered-in/k8s-manifest`
3. **K8s Manifest Repo** — `deployments/stg-lawyered-in-website/deployment.yaml` must exist and have an `image:` line in the expected format
