# 📘 Staging EKS Secret Management: Manual Integration & Rollout Handbook

Welcome! This handbook contains the absolute, step-by-step manual integration workflow to deploy the **External Secrets Operator (ESO)**, configure **AWS IAM Roles for Service Accounts (IRSA)**, and securely externalize all application secrets in your staging EKS cluster.

---

## 🚀 Rollout Phases Checklist
- [ ] **Phase 1:** Install External Secrets Operator (ESO) via Helm
- [ ] **Phase 2:** AWS Console & IAM Configuration (Policy, Trust, & Role)
- [ ] **Phase 3:** Deploy EKS Namespace & IRSA ServiceAccount
- [ ] **Phase 4:** Create Staging ClusterSecretStore (AWS Integration)
- [ ] **Phase 5:** Deploy Sync Rules (ExternalSecret) & Verify Secret Generation
- [ ] **Phase 6:** Rollout Application Workloads & Redis Clean Manifests

---

## 🛠️ Phase-by-Phase Manual Guide

### 📦 PHASE 1: Install External Secrets Operator (ESO) via Helm
First, we must deploy the ESO controller inside your EKS cluster in its own isolated system namespace.

1. **Add the official Helm repository:**
   ```bash
   helm repo add external-secrets https://charts.external-secrets.io
   ```
2. **Refresh your local Helm chart index:**
   ```bash
   helm repo update
   ```
3. **Install the operator in the `external-secrets` namespace with CRDs enabled:**
   ```bash
   helm install external-secrets external-secrets/external-secrets `
     --namespace external-secrets `
     --create-namespace `
     --set installCRDs=true
   ```
4. **Verify the operator pods are running successfully:**
   ```bash
   kubectl get pods -n external-secrets
   ```
   > [!NOTE]
   > Make sure all three pods (`external-secrets`, `external-secrets-webhook`, and `external-secrets-cert-controller`) are in `Running` status before proceeding.

---

### ☁️ PHASE 2: AWS Configuration (IAM Policy & IAM Role for ServiceAccount)
Configure AWS to trust EKS and allow the operator pods to fetch staging credentials securely.

#### **Step 2.1: Locate EKS OIDC Provider Details**
1. Get the OIDC URL and ARN for your staging cluster:
   ```bash
   aws eks describe-cluster --name eks-cluster-np --query "cluster.identity.oidc.issuer" --output text
   ```
   *Note: This will return a URL like `https://oidc.eks.ap-south-1.amazonaws.com/id/YOUR_EKS_OIDC_ID`.*

#### **Step 2.2: Create the IAM Policy**
This policy restricts access to staging secrets only.
1. Open **AWS Console** ➔ **IAM** ➔ **Policies** ➔ **Create Policy**.
2. Go to the **JSON** tab and paste the following:
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
3. Name the policy **`ESOStgSecretsPolicy`** and click **Create**.

#### **Step 2.3: Create the IAM Role (IRSA)**
Create a role that trusts your EKS cluster's identity provider.
1. Open **IAM** ➔ **Roles** ➔ **Create Role**.
2. Select **Web Identity** as the trust entity.
3. Select your EKS OIDC URL as the **Identity Provider** and `sts.amazonaws.com` as the **Audience**.
4. Click Next, then select the **`ESOStgSecretsPolicy`** policy you created.
5. Name the role **`ESOStgSharedRole`**.
6. Before creating, edit the **Trust Relationship JSON** to specify the namespace `stg` and ServiceAccount `eso-stg-shared`:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::857277800188:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/YOUR_EKS_OIDC_ID"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "oidc.eks.ap-south-1.amazonaws.com/id/YOUR_EKS_OIDC_ID:sub": "system:serviceaccount:stg:eso-stg-shared",
             "oidc.eks.ap-south-1.amazonaws.com/id/YOUR_EKS_OIDC_ID:aud": "sts.amazonaws.com"
           }
         }
       }
     ]
   }
   ```
7. Click **Create Role** and copy its ARN (e.g. `arn:aws:iam::857277800188:role/ESOStgSharedRole`).

---

### ☸️ PHASE 3: Deploy EKS Namespace & ServiceAccount
1. Open `eso-stg-setup.yaml` and verify that the `role-arn` matches the exact role ARN from Step 2.3:
   ```yaml
   annotations:
     eks.amazonaws.com/role-arn: arn:aws:iam::857277800188:role/ESOStgSharedRole
   ```
2. Apply the configuration to EKS:
   ```bash
   kubectl apply -f c:\Users\PavanSD\Downloads\resources\resources\k8s-manifest-staging\eso-stg-setup.yaml
   ```

---

### 🗝️ PHASE 4: Deploy the ClusterSecretStore
Create the integration link inside EKS.
1. Apply the staging ClusterSecretStore:
   ```bash
   kubectl apply -f c:\Users\PavanSD\Downloads\resources\resources\k8s-manifest-staging\clustersecretstore-stg.yaml
   ```
2. Verify the status is Valid:
   ```bash
   kubectl get clustersecretstore
   ```

---

### 🌀 PHASE 5: Deploy Sync Rules (Generate Secrets)
Fetch raw configurations from AWS Secrets Manager and convert them into EKS secrets.
1. Apply the sync configurations:
   ```bash
   kubectl apply -f c:\Users\PavanSD\Downloads\resources\resources\k8s-manifest-staging\external-secrets.yaml
   ```
2. **Verify native secrets generation:**
   ```bash
   kubectl get secrets -n stg
   ```
   > [!TIP]
   > You will immediately see all **15 application secrets** (such as `core-platform-be-secret`, `prosper-be-secret`, etc.) created and active inside the staging namespace!

---

### 🚢 PHASE 6: Deploy Clean Microservices & Redis
Since all native secrets are safely generated inside your cluster, you can now rollout your workload manifests!

1. **Deploy all clean microservices:**
   ```bash
   kubectl apply -R -f c:\Users\PavanSD\Downloads\resources\resources\k8s-manifest-staging\deployments
   ```
2. **Deploy the isolated Redis deployments:**
   ```bash
   kubectl apply -R -f c:\Users\PavanSD\Downloads\resources\resources\k8s-manifest-staging\redis-manifest\deployments
   ```
3. **Deploy the ArgoCD configurations to link your GitOps pipeline:**
   *   Core applications:
       ```bash
       kubectl apply -R -f c:\Users\PavanSD\Downloads\resources\resources\k8s-manifest-staging\argocd_manifest
       ```
   *   Redis workloads:
       ```bash
       kubectl apply -R -f c:\Users\PavanSD\Downloads\resources\resources\k8s-manifest-staging\redis-manifest\argocd-redis-manifests
       ```

---

### 🔍 Verification Commands
*   Watch pod logs to ensure perfect connectivity:
    ```bash
    kubectl logs -f -l app=stg-core-platform-be -n stg
    ```
*   Describe an ExternalSecret to diagnose sync issues:
    ```bash
    kubectl describe externalsecret core-platform-be-secret -n stg
    ```
