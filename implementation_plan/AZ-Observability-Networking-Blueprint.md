# 🏛️ Lawyered Platform Stack: End-to-End Networking & Observability Architecture Blueprint (A to Z)
**Project:** AWS EKS GitOps Infrastructure (Lawyered Platform)  
**Topic:** Consolidated Reference Architecture Guide — From Browser Request to Datadog Observability, EKS System Pods, and Mutually Secure DB Access

---

## 🗺️ The Complete End-to-End Traffic & Telemetry Map

This diagram visualizes how a user request flows into the cluster, how microservices securely talk to database layers internally, and how telemetry data is shipped to Datadog:

```
+---------------------------------------------------------------------------------------------------------+
|                                              P U B L I C   I N T E R N E T                              |
|                                                                                                         |
|       [ Browser Client: prosper.lawyered.in ]               [ Browser Client: api-prosper.lawyered.in ] |
|                          |                                                       |                      |
+--------------------------|-------------------------------------------------------|----------------------+
                           | (1. DNS CNAME Query)                                  | (1. DNS CNAME Query)
                           v                                                       v
            +-----------------------------------------------------------------------------+
            |                  Route 53 / Cloudflare DNS (Domain Directory)               |
            |       Resolves both domains to: k8s-laweryerdnpgroup...elb.amazonaws.com     |
            +-----------------------------------------------------------------------------+
                                                   |
                                                   v (2. Traffic enters AWS via IGW)
            +-----------------------------------------------------------------------------+
            |                 AWS Physical Application Load Balancer (ALB)                |
            |                                                                             |
            |   Rule 1 (Host: prosper.lawyered.in) ----> Directs to Target Group FE       |
            |   Rule 2 (Host: api-prosper.lawyered.in) --> Directs to Target Group BE       |
            |   Rule 3 (Host: argocd-prod.lawyered.in) --> Directs to Target Group Argo     |
            +-----------------------------------------------------------------------------+
                     /                                       |
    (3. Direct Pod IP routing via Private Subnets)           |
                   /                                         | (3. Direct Pod IP routing)
                  v                                          v
      +-----------------------------+          +-----------------------------+
      |  EKS Pod: prod-prosper-fe   |          |  EKS Pod: prod-prosper-be   |
      |  (Pod IP: 10.200.45.12:80)  |          |  (Pod IP: 10.200.45.99:8080)|
      +-----------------------------+          +-----------------------------+
                                                              |
                                                              | (4. Resolves secret database credentials)
                                                              |   External Secrets Operator pulls from:
                                                              |   [ AWS Secrets Manager: db-secrets ]
                                                              |
                                                              v (5. SQL Connection on Port 3306)
                                               +------------------------------------+
                                               |       AWS RDS Security Group       |
                                               |  Allows EKS Node SG Ingress Only   |
                                               +------------------------------------+
                                                              |
                                                              v (6. Reads/Writes Private Data)
                                               +------------------------------------+
                                               |    AWS RDS MySQL (Staging/Prod)    |
                                               |        (database_subnets)          |
                                               +------------------------------------+

===========================================================================================================
                                       O B S E R V A B I L I T Y   F L O W
===========================================================================================================

  +---------------------------+       +----------------------------+       +----------------------------+
  | EKS Pods (DaemonSet):     |       | AWS Managed Resources:     |       | Application Containers:    |
  | Datadog Agent (kube-system)       | RDS, Bedrock, VPC Flow Logs|       | Env Variables & Annotations|
  +-------------+-------------+       +-------------+--------------+       +-------------+--------------+
                |                                   |                                    |
                | (Host telemetry & pod logs)       | (IAM Role metrics scraping)        | (APM Traces & JSON parsing)
                |                                   |                                    |
                +-----------------------------------+------------------------------------+
                                                    |
                                                    v (Secure HTTPS Telemetry Ingestion)
                                    +-----------------------------------+
                                    |    Datadog Cloud Platform (SaaS)  |
                                    |   Logs, APM, Tracing, Dashboards  |
                                    +-----------------------------------+
```

---

## 1. Pillar 1: External to Internal Networking (The Ingress & ALB Layer)

### A. The Core Concepts
1. **Ingress (The Rulebook):** An `Ingress` resource is a declarative config file stored inside EKS's `etcd` database. It specifies your routing logic (e.g., *"If domain is `prosper.lawyered.in`, send traffic to service `prod-prosper-fe`"*). It has no physical computing power itself.
2. **Ingress Controller (The Translator & Operator):** The `aws-load-balancer-controller` is an active pod running in `kube-system`. It listens to changes in `etcd`, translates those rules, and uses AWS API calls (`CreateLoadBalancer`, `ModifyListenerRules`) to program your physical AWS infrastructure.
3. **The Shared ALB Grouping Magic (`group.name`):**
   Having a separate Application Load Balancer (ALB) for each of your 15+ microservices is highly expensive. By including this annotation in all your Ingress manifests:
   ```yaml
   alb.ingress.kubernetes.io/group.name: laweryerd-np-group
   ```
   The Ingress Controller intelligently commands AWS to bundle all 15 different domains under **exactly one physical AWS ALB**. It uses **ALB Listener Rules** to route requests by evaluating the HTTP `Host` header.

### B. The End-to-End Request Path (Step-by-Step)
1. **User Request:** A user enters `prosper.lawyered.in` in their browser.
2. **DNS Resolution:** Route 53 or Cloudflare evaluates the CNAME record and resolves the domain to your single shared AWS ALB URL.
3. **ALB Routing Rules:** The request hits the AWS ALB. The ALB inspects the HTTP headers:
   * Host is `prosper.lawyered.in` ➡️ Redirect request to **Target Group A (Frontend)**.
   * Host is `api-prosper.lawyered.in` ➡️ Redirect request to **Target Group B (Backend)**.
4. **Target Group (IP Mode):** Your Ingress is configured with `alb.ingress.kubernetes.io/target-type: ip`. This means the Ingress Controller has registered the **actual Pod IP** (e.g., `10.200.45.12`) directly inside the AWS Target Group. The ALB bypasses EKS node hops and routes traffic straight to the pod inside the EKS VPC Private Subnet.

---

## 2. Pillar 2: Mutually Secure Internal Communication (FE ➡️ BE ➡️ DB)

Inside your EKS cluster, applications must coordinate with each other and external databases securely:

### A. Frontend to Backend Communication
* **Client-Side SPA Calls:** Standard Frontend code running in the client's web browser calls the API via the public internet:
  `https://api-prosper.lawyered.in/api/v1/...` (passing through Route 53 ➡️ ALB ➡️ Backend Pod).
* **Server-Side Rendered (SSR) Calls:** If the Frontend server-side code needs to call the Backend internally without exiting the cluster, it uses the native Kubernetes **`ClusterIP` Service** resolved by **`CoreDNS`**:
  `http://prod-prosper-be-service.prod.svc.cluster.local:8080` (Highly secure, ultra-low latency).

### B. Backend to Database (RDS/Aurora/Redis) Communication
Your databases are managed AWS services living in EKS-external subnets. Communication is established securely through three mechanisms:
1. **VPC Networking:** EKS Nodes (where BE pods run) and RDS instances share the **same AWS VPC**. They route traffic internally across private subnets without exposing database ports to the public internet.
2. **Security Group Firewalls:** The RDS database is locked down with a security group. It only accepts inbound connections on Port `3306` (MySQL) or `6379` (Redis) originating from the **EKS Node Security Group**.
3. **Secret Injection (ESO):**
   * Database credentials (username/password) are stored in **AWS Secrets Manager**.
   * The **`external-secrets` operator (ESO)** running in your cluster pulls these credentials automatically and generates a native Kubernetes Secret.
   * Your Backend Deployment binds these secrets as environment variables (`DB_HOST`, `DB_PASSWORD`) directly into the pod container memory.

---

## 3. Pillar 3: EKS Core System Services (`kube-system` Pods)

The EKS cluster depends on core system pods running in the `kube-system` namespace to orchestrate resources, scaling, network, and storage:

| Pod Name Pattern | Official Service Name | Core Operational Duty |
|---|---|---|
| **`aws-load-balancer-controller`** | AWS Ingress Controller | Watches Ingress resources inside EKS and automatically provisions/updates your physical AWS ALB. |
| **`aws-node`** | AWS VPC CNI Plugin | Connects EKS network directly with AWS VPC. Allocates actual VPC private IP addresses directly to Kubernetes pods. |
| **`cluster-autoscaler`** | Cluster Autoscaler | Monitors EKS resource exhaustion. Auto-spins new EC2 instances to node groups under heavy load; destroys nodes to save costs when idle. |
| **`coredns`** | CoreDNS | The internal phonebook of EKS. Resolves internal service names (e.g., `prod-prosper-be`) to their current pod IP addresses. |
| **`ebs-csi-controller` / `ebs-csi-node`** | AWS EBS CSI Driver | Automatically provisions, attaches, and mounts AWS EBS persistent storage volumes to pods (e.g., Redis databases). |
| **`kube-proxy`** | Kube-Proxy | The networking router inside every node. Maintains local network rules (IP tables) to forward cluster IP traffic. |
| **`metrics-server`** | Metrics Server | Gathers real-time CPU and Memory consumption data from all nodes/pods (enabling HPA and Autoscaling). |

---

## 4. Pillar 4: Platform-Wide Observability (Datadog Integration Flow)

Datadog integrates across three distinct layers to gather telemetry without storing data inside your cluster, preventing disk space starvation:

1. **AWS Infrastructure Level (Terraform):**
   * Terraform provisions an IAM Policy and Cross-Account IAM Role (`DatadogAWSIntegrationRole`).
   * Datadog's official AWS account ID (`464622532012`) assumes this role via a unique **External ID** to scrape CloudWatch metrics for S3, Bedrock, ALBs, and RDS databases.
2. **Kubernetes EKS Cluster Level (ArgoCD / GitOps):**
   * Deployed via ArgoCD as a system `DaemonSet` on every single EKS worker node.
   * Pods mount the host node's log directories (`/var/log/pods`) and socket volumes to collect EKS system metrics and all container console logs.
3. **Application Level (APM Tracing & Log Parsing):**
   * **APM Traces:** Microservice pods route execution traces to the local host's node agent using the Downward API to fetch the parent node's IP:
     ```yaml
     env:
       - name: DD_Agent_Host
         valueFrom:
           fieldRef:
             fieldPath: status.hostIP
     ```
   * **Structured Logs:** Microservices output logs to stdout/stderr in JSON format. Pod annotations tell Datadog how to parse and index these log files:
     ```yaml
     annotations:
       ad.datadoghq.com/app.logs: '[{"source": "nodejs", "service": "prosper-be"}]'
     ```
   * **SaaS Storage:** All telemetry is pushed instantly via HTTPS API directly to the secure **Datadog SaaS Platform**, where you can visualize logs, traces, and metrics in real-time.
