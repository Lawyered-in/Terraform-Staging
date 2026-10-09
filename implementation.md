# Implementing Code & API Quality Gates in AWS CodePipeline

This guide provides a step-by-step implementation plan to ensure that **no code errors or broken APIs** are deployed by your CI/CD pipeline. We will achieve this by adding **Linting/Unit Tests** before the build, and dynamic **API Integration Testing (Newman)** before the deployment stage.

---

## Step 1: Catching Code Errors (Linting & Unit Tests)

Before Docker builds the image, we want to fail the pipeline immediately if there are syntax errors, failing unit tests, or code smells. 

You can inject these tests into your existing Build stage without modifying the underlying Terraform module by passing them via your module call in `resources/templates/main.tf` or `terraform.tfvars`.

### Action Required:
Update your module instantiation (where you call `module "codepipeline"`) to include `custom_pre_build_commands`.

```hcl
module "codepipeline" {
  source = "../modules/codepipeline"
  # ... your other existing variables ...

  # Injecting Code Quality Checks before the Docker Build
  custom_pre_build_commands = [
    "echo ----------------------------------------",
    "echo 🛑 Phase 1: Code Quality & Unit Testing",
    "echo ----------------------------------------",
    "echo Installing dependencies...",
    "npm ci", # Or pip install -r requirements.txt
    
    "echo Running Code Linter...",
    "npm run lint", # Fails the pipeline if syntax is bad
    
    "echo Running Unit Tests...",
    "npm run test", # Fails the pipeline if unit tests break
    
    "echo ✅ Code Quality Passed. Proceeding to Docker Build...",
    "echo Logging in to Amazon ECR...",
    "aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${var.ecr_repository_url}",
    "COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)",
    "IMAGE_TAG=$${COMMIT_HASH:=latest}"
  ]
}
```

---

## Step 2: Modifying Terraform for Dynamic API Testing

To prevent broken APIs from deploying, we will create a dedicated CodeBuild project that pulls the newly built image, runs it dynamically, and executes API tests against it using **Newman (Postman CLI)**.

### Action Required in `resources/modules/codepipeline/variables.tf`:
Add a toggle variable so you can enable/disable API tests per environment.

```hcl
variable "enable_api_tests" {
  description = "Enable dynamic API testing using Newman before deployment"
  type        = bool
  default     = true
}
```

### Action Required in `resources/modules/codepipeline/main.tf`:
**1. Add the API Test CodeBuild Project:**
Add this block at the bottom of the file to define the runner.

```hcl
# -------------------------------------------------------------------
# CodeBuild API Testing Project
# -------------------------------------------------------------------
resource "aws_codebuild_project" "api_test" {
  count        = var.enable_api_tests ? 1 : 0
  name         = "${var.pipeline_name}-api-test"
  description  = "Dynamic API tests using Postman/Newman for ${var.pipeline_name}"
  service_role = aws_iam_role.pipeline.arn # Or your specific build role

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true # Required to run Docker-in-Docker

    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.ecr_repository_url
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = yamlencode({
      version = 0.2
      phases = {
        pre_build = {
          commands = [
            "echo 📦 Installing Newman (Postman CLI)...",
            "npm install -g newman",
            "echo 🔑 Logging into ECR...",
            "aws ecr get-login-password --region ${data.aws_region.current.id} | docker login --username AWS --password-stdin $ECR_REPOSITORY_URL"
          ]
        }
        build = {
          commands = [
            "echo 🚀 Starting the newly built Docker container locally...",
            "docker run -d -p 8080:8080 $ECR_REPOSITORY_URL:$IMAGE_TAG",
            
            "echo ⏳ Waiting for API to initialize (15 seconds)...",
            "sleep 15",
            
            "echo 🧪 Executing Postman API Collection against localhost:8080...",
            # This line runs your tests. If any assertion fails, Newman exits with a non-zero code, failing the pipeline.
            "newman run tests/postman_collection.json --env-var baseUrl=http://localhost:8080"
          ]
        }
      }
    })
  }
}
```

**2. Inject the Stage into `aws_codepipeline` block:**
Find your `aws_codepipeline` resource in `main.tf` and add this dynamic stage right **before the Deploy stage** (and after SecurityScan).

```hcl
  dynamic "stage" {
    for_each = var.enable_api_tests ? [1] : []
    content {
      name = "APITesting"
      action {
        name             = "APITesting"
        category         = "Test"
        owner            = "AWS"
        provider         = "CodeBuild"
        version          = "1"
        input_artifacts  = ["source_output"]
        
        configuration = {
          ProjectName   = aws_codebuild_project.api_test[0].name
          PrimarySource = "source_output"
          # Dynamically resolve the IMAGE_TAG exported from the Build stage
          EnvironmentVariables = jsonencode([
            {
              name  = "IMAGE_TAG"
              value = format("#{%s.IMAGE_TAG}", coalesce(var.build_namespace, "BuildVariables"))
              type  = "PLAINTEXT"
            }
          ])
        }
      }
    }
  }
```

---

## Step 3: Setting Up the API Tests in Your Repository

For the above pipeline to work, your application's GitHub repository needs to contain the Postman tests.

### Action Required in the Application Repository:

1. **Create the Tests:**
   - Open the **Postman** desktop app.
   - Create a new Collection named `App-API-Tests`.
   - Add requests to your collection (e.g., `GET /health`, `POST /login`).
   - For every request, write assertions in the **"Tests"** tab. Example:
     ```javascript
     // Check if status is 200
     pm.test("Status code is 200", function () {
         pm.response.to.have.status(200);
     });
     
     // Check if API returns expected JSON
     pm.test("Response contains success message", function () {
         var jsonData = pm.response.json();
         pm.expect(jsonData.status).to.eql("success");
     });
     ```
   - **Crucial:** Use variables for your URL. Instead of `http://localhost:8080/health`, use `{{baseUrl}}/health`. This allows Newman to inject the URL dynamically.

2. **Export the Collection:**
   - Click the three dots `...` next to your Collection in Postman -> **Export** -> **Collection v2.1 (Recommended)**.
   - Save the file as `postman_collection.json`.

3. **Commit to Repository:**
   - In your application's root directory, create a folder named `tests/`.
   - Move `postman_collection.json` into the `tests/` folder.
   - Commit and push to GitHub.

---

## Final Workflow Overview

Once implemented, your pipeline will execute flawlessly in this order:

1. **Source:** Code is pulled from GitHub.
2. **Build (Pre-build phase):** `npm run lint` and `npm run test` execute. ❌ *Fails here if syntax is bad.*
3. **Build (Build phase):** Docker image is built and pushed to ECR.
4. **SecurityScan:** Semgrep, Syft, and Grype evaluate vulnerabilities. ❌ *Fails here if vulnerabilities exceed thresholds.*
5. **APITesting:** CodeBuild pulls the image, runs it locally, and fires Postman tests at it. ❌ *Fails here if APIs return 500s or assertions fail.*
6. **Deploy:** ArgoCD/K8s manifest is updated. ✅ *Only triggers if Code is clean, Secure, and APIs function perfectly.*
