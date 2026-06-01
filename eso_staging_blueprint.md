# EKS Secret Management: Replicating Production ESO Setup in Staging

This blueprint outlines the current architecture of the **External Secrets Operator (ESO)** and **AWS Secrets Manager** integration on your production EKS cluster and provides a step-by-step implementation guide to replicate this exact setup for your **Staging** environment.

---

## 1. Production Secret Management Architecture

In production, sensitive environment variables are kept out of Git repositories and instead fetched dynamically from AWS Secrets Manager. 

Here is the step-by-step lifecycle of a production secret:

```mermaid
sequenceDiagram
    autonumber
    participant App as Application Pod (prod-core-platform-be)
    participant Secret as Native K8s Secret (core-platform-be-secret)
    participant ESO as External Secrets Operator
    participant Store as ClusterSecretStore (aws-secrets-manager)
    participant SA as ServiceAccount (eso-prod-shared)
    participant AWS as AWS Secrets Manager (prod/core-platform-be)

    Note over App, AWS: Step 1: Authentication (IRSA)
    ESO ->> Store: Watches ExternalSecret & connects via Store
    Store ->> SA: References eso-prod-shared SA in 'prod'
    SA ->> AWS: EKS OIDC verifies JWT token & assumes IAM Role (ESOProdSharedRole)
    
    Note over App, AWS: Step 2: Synchronization (Polled every 1 hour)
    ESO ->> AWS: Fetches secret "prod/core-platform-be"
    AWS -->> ESO: Returns JSON credentials
    ESO ->> Secret: Creates/updates Opaque Kubernetes Secret
    
    Note over App, AWS: Step 3: Pod Consumption
    App ->> Secret: Inject all env variables using envFrom.secretRef
```

### Current Production EKS Configuration
1. **ServiceAccount (`eso-prod-shared` in `prod` namespace):**
   Annotated with the production IAM Role:
   ```yaml
   eks.amazonaws.com/role-arn: arn:aws:iam::857277800188:role/ESOProdSharedRole
   ```
2. **ClusterSecretStore (`aws-secrets-manager`):**
   Connects to AWS Secrets Manager (`ap-south-1`) utilizing the JWT token projected on the `eso-prod-shared` ServiceAccount.
3. **ExternalSecret (`core-platform-be-secret` in `prod` namespace):**
   Extracts keys from AWS Secrets Manager path `prod/core-platform-be` and dynamically creates the Kubernetes Secret `core-platform-be-secret`.
4. **Deployment (`prod-core-platform-be`):**
   Consumes all credentials cleanly via:
   ```yaml
   envFrom:
     - secretRef:
         name: core-platform-be-secret
   ```

---

## 2. Staging Replication Strategy

To replicate this in staging, we will use the **same EKS cluster** but deploy to a dedicated namespaced environment (`stg`) using a matching security profile.

Here is the concrete 6-step blueprint:

### Step 1: Create the `stg` Namespace and ServiceAccount
Save this file as `eso-stg-setup.yaml` in your manifests folder:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: stg
  labels:
    environment: staging
    managed-by: manual
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eso-stg-shared
  namespace: stg
  labels:
    environment: staging
    managed-by: external-secrets-operator
  annotations:
    # Point this to the new staging IAM Role we will create in Step 2
    eks.amazonaws.com/role-arn: arn:aws:iam::857277800188:role/ESOStgSharedRole
```

Run the following command to deploy it:
```bash
kubectl apply -f eso-stg-setup.yaml
```

---

### Step 2: Provision Staging AWS IAM Role (`ESOStgSharedRole`)
Create an IAM role that grants access strictly to staging secrets. 

#### Trust Relationship Policy
Configure the Trust Relationship on `ESOStgSharedRole` to allow OIDC credentials matching the `stg` namespace's ServiceAccount:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::857277800188:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/77586BABBD937DB9B577603121ED53F0"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-south-1.amazonaws.com/id/77586BABBD937DB9B577603121ED53F0:sub": "system:serviceaccount:stg:eso-stg-shared",
          "oidc.eks.ap-south-1.amazonaws.com/id/77586BABBD937DB9B577603121ED53F0:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

#### Permission Policy
Attach a policy (`ESOStgSecretsPolicy`) to the role, restricting access specifically to secrets prefixed with `staging/`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-south-1:857277800188:secret:staging/*"
    }
  ]
}
```

---

### Step 3: Create the Staging ClusterSecretStore
Save this file as `clustersecretstore-stg.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager-stg
  labels:
    environment: staging
    managed-by: external-secrets-operator
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-south-1
      auth:
        jwt:
          serviceAccountRef:
            name: eso-stg-shared
            namespace: stg
```

Deploy the ClusterSecretStore:
```bash
kubectl apply -f clustersecretstore-stg.yaml
```

---

### Step 4: Populate Staging Secrets in AWS Secrets Manager
Use the AWS CLI (or AWS Console) to create the secret container under `staging/core-platform-be`:

```bash
aws secretsmanager create-secret \
  --name "staging/core-platform-be" \
  --description "Staging environment secrets for core-platform-be" \
  --secret-string '{"DATABASE_URL":"postgresql://core_dev_user:955SHPIb7+wy@core-uat-db.cj446ammul0i.ap-south-1.rds.amazonaws.com:5432/core_dev_db","AWS_ACCESS_KEY_ID":"AKIAX5ZI6NFPLCP5UVMZ","AWS_SECRET_ACCESS_KEY":"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","GOOGLE_PRIVATE_KEY":"-----BEGIN PRIVATE KEY-----\nMIIEuQIBADANBgkqhkiG9w0BAQEFAASCBKMwggSfAgEAAoIBAQCnKkkHkdJBHvZ1\n...","BETTER_AUTH_SECRET":"aT16owOg4X/TZBoeR60Kx0UFk4+EqNtVYzdwwwVj5I8=","REDIS_URL":"redis://:Engineering%402026@34.131.182.199:6379"}' \
  --region ap-south-1
```

---

### Step 5: Deploy the Staging ExternalSecret Manifest
Create an `ExternalSecret` that instructs the running External Secrets Operator to sync the secret into your `stg` namespace:

`stg-core-platform-be-secret.yaml`:
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: core-platform-be-secret
  namespace: stg
  labels:
    app: stg-core-platform-be
    environment: staging
    managed-by: external-secrets-operator
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager-stg
    kind: ClusterSecretStore
  target:
    name: core-platform-be-secret
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: staging/core-platform-be
```

Apply the manifest:
```bash
kubectl apply -f stg-core-platform-be-secret.yaml
```

Once applied, verify successful synchronization:
```bash
kubectl get externalsecret core-platform-be-secret -n stg
# STATUS should show: SecretSynced
```

---

### Step 6: Refactor the Deployment to Consume Secrets
Open `deployments/stg-core-platform-be/deployment.yaml` and refactor it by replacing the hardcoded environment variables with an `envFrom` block:

```yaml
spec:
  containers:
    - name: stg-core-platform-be-api
      # ... image and other configurations ...
      envFrom:
        - secretRef:
            name: core-platform-be-secret
```

This ensures your Git repositories are 100% clean and free of plain-text passwords or secret keys.
