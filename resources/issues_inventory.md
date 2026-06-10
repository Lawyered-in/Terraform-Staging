# 📒 Issues Inventory & Solutions Log

This document tracks all significant infrastructure and CI/CD challenges encountered during the setup and how they were resolved using best practices.

---

### 1. Issue: Argo CD Ingress Circular Dependency
- **Symptom**: Terraform was unable to destroy or update the Argo CD Ingress because the `kubernetes.io/target-group` and ALB Controller had a mutual dependency on the Argo CD Helm chart.
- **Root Cause**: Managing the Ingress *inside* the Helm chart created a provider dependency loop.
- **Fix**: 
    - Moved the Ingress management to a standalone Kubernetes manifest (`templates/main.tf`).
    - Used the `kubernetes_manifest` resource to manage it externally.
- **Best Practice**: Treat entry-point networking (ALB/Ingress) as a higher-level resource than the platform (Argo CD) itself.

### 2. Issue: Docker Hub Rate Limit (429 Error)
- **Symptom**: CodeBuild projects failed during the `docker build` phase with the error: `429 Too Many Requests: You have reached your unauthenticated pull rate limit`.
- **Root Cause**: Many CodeBuild runners share a small set of NAT gateway IP addresses, hitting Docker Hub's anonymous limits for common images like `node:20-alpine`.
- **Fix**:
    - Refactored the `codepipeline` module to support an **ECR Public Gallery Mirror**.
    - Added a shell loop in the `PRE_BUILD` phase to pull images from `public.ecr.aws/docker/library/` and tag them locally before the build starts.
- **Command Used**:
    ```bash
    for image in $prefetch_images; do 
      docker pull public.ecr.aws/docker/library/$image; 
      docker tag public.ecr.aws/docker/library/$image $image; 
    done
    ```

### 3. Issue: React/Vite vs. Nuxt Build Output Conflict
- **Symptom**: Docker build failed in the second stage with: `COPY --from=builder /app/.output ./.output: not found`.
- **Root Cause**: The user's `Dockerfile` was copied from a Nuxt.js project, but the application was a Vite/React project which outputs to the `dist/` directory.
- **Fix**:
    - Updated the `Dockerfile` to copy from `/app/dist` instead of `/app/.output`.
    - Integrated the `serve` package to handle static application hosting on port 3000.

### 4. Issue: Pipeline Configuration Drift (GitHub Connection)
- **Symptom**: Updating the GitHub connection ARN in `tfvars` did not apply to the existing connection in AWS.
- **Root Cause**: The connection was created manually and was not being managed by Terraform.
- **Fix**: 
    - Used `terraform import` to bring the existing CodeStar connection into the state.
    - Updated the root `main.tf` to reference the resource ARN dynamically.

### 5. Issue: CodeBuild Shell Syntax (Loops)
- **Symptom**: Build failed in `PRE_BUILD` with `syntax error: unexpected end of file`.
- **Root Cause**: Multi-line shell loops in YAML Buildspecs can be interpreted as separate commands, breaking the loop logic.
- **Fix**: Consolidated the entire pre-fetch loop into a **single-line command** with semicolons.

---
*Last updated: April 22, 2026*
