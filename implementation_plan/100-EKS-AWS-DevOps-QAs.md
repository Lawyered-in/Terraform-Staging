# 🎓 The Master DevOps Study Guide: 100 Questions & Answers (A to Z)
g**Project:** AWS EKS & GitOps Infrastructure Platform  
**Topics Covered:** Kubernetes Core, Advanced VPC Networking, ALB Ingress Controllers, Database Security, Secrets Management, Datadog Observability, Terraform IAC, and Real-World Troubleshooting.

---

## 📂 Category 1: Kubernetes & EKS Core Architecture (Q1 - Q15)

### Q1: What is EKS and how does it differ from self-managed Kubernetes?
**A1:** AWS Elastic Kubernetes Service (EKS) is a managed Kubernetes service. AWS manages the availability, scalability, and security of the Kubernetes Control Plane (API Server, `etcd` database, Scheduler, Controller Manager) across multiple Availability Zones, while you only manage the worker nodes (via EC2 Node Groups or Fargate).

### Q2: What is the `etcd` component in the EKS Control Plane?
**A2:** `etcd` is a highly available, distributed key-value store used as Kubernetes' backing store for all cluster data (state, configurations, secrets, and metadata). Only the EKS Control Plane API Server communicates directly with `etcd`.

### Q3: What is a Pod in Kubernetes?
**A3:** A Pod is the smallest deployable computing unit in Kubernetes. It represents a single instance of a running process in your cluster and can contain one or more containers (e.g., your Backend app container and a helper sidecar) that share the same network space, storage, and lifecycle.

### Q4: What is a ReplicaSet?
**A4:** A ReplicaSet's purpose is to maintain a stable set of replica Pods running at any given time. It is used to guarantee the availability of a specified number of identical Pods. You rarely manage ReplicaSets directly; instead, they are managed by Deployments.

### Q5: What is a Kubernetes Deployment?
**A5:** A Deployment is a higher-level controller that manages declarative updates for Pods and ReplicaSets. It allows you to define container images, environment variables, replica counts, and rolling update strategies (e.g., `RollingUpdate` or `Recreate`).
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-lawyered-be
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
```

### Q6: What is a DaemonSet?
**A6:** A DaemonSet ensures that all (or some) Nodes run a copy of a specific Pod. As nodes are added to the cluster, Pods are started on them. As nodes are removed, those Pods are garbage collected. Typical use cases include log collectors (like Datadog Agent) and networking plugins (like `aws-node`).

### Q7: What is a StatefulSet?
**A7:** A StatefulSet is used to manage stateful applications. Unlike a Deployment, a StatefulSet maintains a sticky identity for each of their Pods (e.g., `prod-redis-master-0`, `prod-redis-master-1`). These pods are created sequentially and bind to persistent volumes that persist even if the pod restarts.

### Q8: What is a Kubernetes Service?
**A8:** A Service is an abstract way to expose an application running on a set of Pods as a network service. Since Pods are ephemeral (they die and get recreated with new IPs), the Service provides a stable, permanent IP address and DNS name to route traffic to active Pods using label selectors.

### Q9: What is a `ClusterIP` Service?
**A9:** The default Kubernetes Service type. It exposes the service on a cluster-internal IP address. Choosing this value makes the service only reachable from within the cluster.
```yaml
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
```

### Q10: What is a `NodePort` Service?
**A10:** Exposes the Service on each Node's IP at a static port (in the `30000-32767` range). A `ClusterIP` Service, to which the `NodePort` Service routes, is automatically created. You can contact the `NodePort` Service from outside the cluster by requesting `<NodeIP>:<NodePort>`.

### Q11: What is a `LoadBalancer` Service?
**A11:** Exposes the Service externally using a cloud provider's load balancer (e.g., AWS Classic or Network Load Balancer). Traffic from the external load balancer is automatically routed to the backend Pods.

### Q12: What is the Downward API in Kubernetes?
**A12:** The Downward API allows containers to discover information about themselves or the cluster environment (such as Pod IP, Node IP, Namespace, Labels) without having to query the Kubernetes API server directly.
```yaml
env:
  - name: MY_NODE_IP
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
```

### Q13: What is a Kubernetes Namespace?
**A13:** A Namespace is a logical partition inside a Kubernetes cluster. It allows you to isolate resources, define resource quotas, and configure access control (RBAC) across different environments (e.g., `default`, `kube-system`, `argo-cd`, `prod`).

### Q14: What is the difference between a Pod's `requests` and `limits`?
**A14:** 
* **Requests:** The minimum amount of CPU and Memory guaranteed to a container. The Kubernetes scheduler uses this value to decide which node to place the Pod on.
* **Limits:** The maximum amount of CPU and Memory a container is allowed to consume. If a container exceeds its memory limit, it is Out-Of-Memory (OOM) killed.

### Q15: What is a `Toleration` and `Taint` in Kubernetes?
**A15:** 
* **Taints:** Applied to Nodes, allowing the Node to repel a set of Pods.
* **Tolerations:** Applied to Pods, allowing (but not requiring) the Pods to schedule onto Nodes with matching taints. This is used to dedicate specific nodes for system tasks or specialized workloads (e.g., Datadog running on master nodes).

---

## 🌐 Category 2: Advanced VPC Networking & CNI (Q16 - Q30)

### Q16: What is the AWS VPC CNI Plugin?
**A16:** The VPC Container Network Interface (CNI) is the networking engine for EKS. It runs as a DaemonSet (`aws-node`) and integrates EKS networking directly with your AWS VPC, giving pods the same network performance and IP routing capabilities as native EC2 instances.

### Q17: What does the `aws-node` DaemonSet do on each worker node?
**A17:** It manages AWS Elastic Network Interfaces (ENIs) attached to the EC2 worker nodes. It pre-allocates pools of private IP addresses from the node's subnet and assigns them directly to pods as they start.

### Q18: Why is using VPC CNI better than overlay networks (like Calico or Flannel)?
**A18:** VPC CNI avoids the encapsulation overhead (VxLAN or GENEVE) of overlay networks. Pod-to-Pod and Pod-to-External communication happens natively inside the AWS VPC without additional packet wrapping, providing higher throughput and lower latency.

### Q19: What is an IP address exhaustion issue in EKS, and how do you prevent it?
**A19:** In small VPC subnets, every pod consumes a real VPC private IP address, causing the subnet to run out of IPs quickly. You can prevent this by using **Custom Networking** (assigning pods to a separate secondary CIDR block) or utilizing **Prefix Delegation** to allocate `/28` IP prefixes to ENIs instead of individual IPs.

### Q20: What is EKS Pod ENI Multi-IP mode?
**A20:** It is the default mode where a single ENI attached to an EC2 instance is allocated multiple secondary private IP addresses. Each of these secondary IPs is mapped directly to a running pod.

### Q21: What is the EKS Cluster Security Group?
**A21:** An EKS-managed security group automatically created during cluster provision. It enables communication between the managed control plane (API Server) and your worker nodes.

### Q22: What are public and private subnets in EKS VPC architecture?
**A22:** 
* **Public Subnets:** Have a direct route to the Internet Gateway (IGW). External-facing resources like ALBs are deployed here.
* **Private Subnets:** Have no direct internet route. Worker nodes and internal pods run here, routing outbound traffic through a NAT Gateway.

### Q23: What is the NAT Gateway's role in EKS?
**A23:** The NAT Gateway sits in a public subnet and translates the private IP addresses of pods running in private subnets into a single public IP, enabling pods to safely fetch external dependencies (like Datadog APIs or GitHub) without being publicly exposed.

### Q24: What is a Database Subnet?
**A24:** A dedicated subnet tier inside your VPC isolated from both EKS nodes and the public internet. It holds your RDS databases, ensuring they are only accessible through strict private routing rules.

### Q25: How does EKS communicate with RDS internally?
**A25:** Traffic travels purely over the AWS VPC backbone. The Backend Pod IP initiates a connection to the RDS private DNS endpoint. The packet flows across subnets internally without exiting to the internet.

### Q26: What is a Transit Gateway?
**A26:** A cloud router used to connect multiple VPCs and on-premises networks together. In large enterprises, it connects the EKS staging/production VPC to a corporate shared-services VPC.

### Q27: What is VPC Peering?
**A27:** A direct, 1-to-1 network connection between two VPCs. It allows EKS pods in VPC-A to communicate privately and securely with resources (like a legacy database) in VPC-B.

### Q28: What are VPC Flow Logs?
**A28:** A feature that captures detailed IP traffic going to and from network interfaces in your VPC. Datadog scrapes these logs to provide network topology maps and security auditing.

### Q29: What is an Internet Gateway (IGW)?
**A29:** The AWS resource that connects your VPC to the public internet, allowing the Application Load Balancer to receive public user requests.

### Q30: What is a Route Table in EKS VPC?
**A30:** A set of routing rules that determines where network traffic from your subnets is directed. Private subnets route `0.0.0.0/0` traffic to the NAT Gateway, while public subnets route it to the IGW.

---

## 🏛️ Category 3: Ingress & AWS ALB Controller (Q31 - Q50)

### Q31: What is an Ingress class in EKS?
**A31:** A parameter that tells the cluster which controller should process the Ingress resource. For AWS Load Balancer Controller, the class is `alb`.
```yaml
annotations:
  kubernetes.io/ingress.class: alb
```

### Q32: What annotation is used to create a public internet-facing ALB?
**A32:** `alb.ingress.kubernetes.io/scheme: internet-facing`.
Without this, the controller will create an internal ALB accessible only inside the VPC.

### Q33: How does `target-type: ip` work in EKS ALB?
**A33:** The controller registers the actual Kubernetes Pod IPs directly into the AWS Target Group. Client requests are routed from the ALB straight to the target pod, completely bypassing the EC2 instance's NodePort.

### Q34: What is the alternative to `target-type: ip` and how does it work?
**A34:** `target-type: instance`. The ALB registers the EC2 worker nodes themselves as targets. The ALB sends traffic to a specific `NodePort` on the EC2 instances, and `kube-proxy` routes it internally to the actual pod.

### Q35: Why does `target-type: ip` provide better performance?
**A35:** It removes the network hop through the EC2 Node's interface and the internal iptables routing lookup managed by `kube-proxy`, reducing latency and avoiding network saturation on worker nodes.

### Q36: What is ALB Ingress Grouping?
**A36:** A powerful optimization feature where multiple EKS Ingress resources share a single physical Application Load Balancer.
```yaml
alb.ingress.kubernetes.io/group.name: laweryerd-np-group
```

### Q37: How does ALB differentiate traffic under a shared Group?
**A37:** The AWS Load Balancer Controller merges all Ingress host and path rules into **Listener Rules** on the single shared ALB. The ALB routes traffic by matching the HTTP `Host` header (e.g., `prosper.lawyered.in` vs `finvica.com`).

### Q38: What does `alb.ingress.kubernetes.io/group.order` do?
**A38:** It defines the priority order of the rules inside the ALB. Rules with lower numbers (e.g., `10`) are evaluated first. If a request matches that host, it is routed immediately.
```yaml
alb.ingress.kubernetes.io/group.order: "10"
```

### Q39: How does the ALB Controller handle SSL Termination?
**A39:** The ALB handles the SSL handshake and decrypts the HTTPS traffic using an SSL certificate from AWS Certificate Manager (ACM). It then forwards the decrypted HTTP traffic (Port 80/8080) to the EKS pods internally.

### Q40: What annotation links an ACM certificate to the ALB Ingress?
**A40:** `alb.ingress.kubernetes.io/certificate-arn`.
```yaml
alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:ap-south-1:857277800188:certificate/85d2f5d6-dedc-4b6f-9e16-395fa9b4c778"
```

### Q41: How do you enforce SSL redirect (HTTP to HTTPS) at the ALB level?
**A41:** By adding the `ssl-redirect` annotation, which configures the ALB listener to immediately respond with a `301 Moved Permanently` to port 443 for any incoming Port 80 request.
```yaml
alb.ingress.kubernetes.io/ssl-redirect: "443"
```

### Q42: What does the `listen-ports` annotation define?
**A42:** It specifies the ports the ALB should listen on for incoming traffic (usually HTTP Port 80 and HTTPS Port 443).
```yaml
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
```

### Q43: How does the ALB determine if a Pod is healthy?
**A43:** By calling the path defined in `alb.ingress.kubernetes.io/healthcheck-path` at regular intervals.
```yaml
alb.ingress.kubernetes.io/healthcheck-path: "/healthz"
```

### Q44: What is the `success-codes` annotation used for?
**A44:** It defines the HTTP response codes the ALB should accept as a healthy response from the pod's health check path.
```yaml
alb.ingress.kubernetes.io/success-codes: "200,301,302"
```

### Q45: How does the ALB controller clean up resources when an Ingress is deleted?
**A45:** When you delete an Ingress manifest, the `aws-load-balancer-controller` pod catches the deletion event and immediately sends API requests to AWS to delete the matching listener rules, target groups, or the ALB itself if no other Ingress is using the Group.

### Q46: What is a Target Group in AWS ELB?
**A46:** A logical grouping of targets (IPs or Instances) that receive routed requests from the Load Balancer.

### Q47: What does the ALB Controller's `Reconciliation Loop` mean?
**A47:** The continuous background process where the controller compares the *Desired State* (your applied Ingress YAMLs) with the *Actual State* (the configured ALB in AWS) and automatically executes API commands to resolve any drift.

### Q48: How does ALB handle rolling deployments of EKS pods?
**A48:** As old pods terminate and new pods start, the Ingress Controller automatically registers the new Pod IPs to the Target Group and deregisters the old ones. The ALB drains connections gracefully from the old pods.

### Q49: What is connection draining (deregistration delay)?
**A49:** The period during which the ALB allows active requests to complete on a pod that is being terminated before cutting off traffic completely.

### Q50: How do you configure public subnets explicitly on an ALB Ingress?
**A50:** Using the `subnets` annotation, passing a comma-separated list of public subnet IDs.
```yaml
alb.ingress.kubernetes.io/subnets: "subnet-12345,subnet-67890"
```

---

## 🔒 Category 4: Security, Secrets & IAM (Q51 - Q65)

### Q51: What is IAM Roles for Service Accounts (IRSA)?
**A51:** A secure mechanism that allows Kubernetes Pods to assume specific AWS IAM Roles. Instead of using hardcoded AWS access keys inside container code, the Pod's ServiceAccount is mapped directly to an IAM Role via OpenID Connect (OIDC).

### Q52: What is an OIDC Provider in EKS?
**A52:** EKS hosts a public OpenID Connect discovery endpoint. By registering this OIDC provider with AWS IAM, IAM can validate cryptographically signed tokens generated by Kubernetes service accounts.

### Q53: How does a pod ServiceAccount reference an IAM Role?
**A53:** By utilizing an annotation in the ServiceAccount manifest:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-lb-controller-sa
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::857277800188:role/eks-lb-controller-role
```

### Q54: How does a Security Group differ from a Network ACL (NACL)?
**A54:** 
* **Security Group:** Stateful, acts at the instance/pod level, evaluates traffic rules before hitting the resource.
* **NACL:** Stateless, acts at the subnet level, evaluates traffic entering/exiting the entire subnet boundary.

### Q55: How do we restrict access to RDS database instances in our stack?
**A55:** We configure the RDS Security Group to only allow inbound traffic on Port 3306 originating from the Security Group ID of the EKS worker nodes.

### Q56: Why is storing DB passwords in Git repository YAML manifests dangerous?
**A56:** Git history is permanent and accessible. Anyone with read access to the repo can expose production database credentials, leading to data breaches or unauthorized access.

### Q57: What is the External Secrets Operator (ESO)?
**A57:** A cluster operator that syncs secret data from external APIs (like AWS Secrets Manager) directly into a native Kubernetes Secret object.
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rds-db-secrets
```

### Q58: What is a `SecretStore` in ESO?
**A58:** A Kubernetes resource that tells ESO *how* to authenticate with your external secret vault (e.g., pointing to the AWS Secrets Manager region using the pod's ServiceAccount role).

### Q59: How does EKS decrypt Kubernetes Secrets?
**A59:** EKS encrypts secrets at rest in `etcd` using an AWS KMS (Key Management Service) key that you define in your Terraform EKS configuration.

### Q60: What is AWS Secrets Manager?
**A60:** A managed AWS service that stores, rotates, and manages credentials, API keys, and database passwords securely in the cloud.

### Q61: What is open-source Secrets rotation?
**A61:** A process managed by AWS Secrets Manager where a Lambda function automatically changes database passwords every X days and updates the secret value without causing application downtime.

### Q62: What is RBAC (Role-Based Access Control) in Kubernetes?
**A62:** A security framework that regulates user and system access to EKS cluster resources based on Roles (rules defining allowed API verbs/actions) and RoleBindings (mapping those roles to specific users or ServiceAccounts).

### Q63: What is the difference between a `Role` and a `ClusterRole`?
**A63:** 
* **Role:** Grants access to resources within a single Namespace.
* **ClusterRole:** Grants access cluster-wide across all namespaces (e.g., listing nodes or namespaces).

### Q64: What is the `aws-auth` ConfigMap in EKS?
**A64:** A special ConfigMap in EKS (`kube-system` namespace) that maps AWS IAM Roles and Users directly to Kubernetes RBAC groups, allowing IAM identity holders to authenticate into the EKS API Server.

### Q65: What is a NetworkPolicy in Kubernetes?
**A65:** A resource that acts as an in-cluster firewall, defining how groups of pods are allowed to communicate with each other and other network endpoints.

---

## 📈 Category 5: Observability & Datadog (Q66 - Q85)

### Q66: What is the Datadog AWS Integration?
**A66:** A cross-account IAM integration where Datadog assumes a role inside your AWS account to scrape metrics from cloud services (RDS, Bedrock, ELB, S3) and send them to the Datadog dashboard.

### Q67: What role does the External ID play in the Datadog AWS integration?
**A67:** It is a cryptographic security token shared between Datadog and AWS that prevents the "Confused Deputy" vulnerability, ensuring only your Datadog tenant can assume the cross-account role.

### Q68: What is the Datadog Kubernetes Agent?
**A68:** An agent deployed on every worker node (via DaemonSet) that acts as a collector for node hardware metrics, EKS cluster events, container console logs, and APM traces.

### Q69: Why do we deploy Datadog Agent as a DaemonSet?
**A69:** It ensures that every worker node in your cluster automatically hosts exactly one collector pod, guaranteeing complete metric coverage as your node counts auto-scale.

### Q70: Where does the Datadog Agent store collected logs inside EKS?
**A70:** It does **not** store logs. It reads them from the host's log directory and streams them over secure HTTPS directly to Datadog's SaaS platform, preserving EKS disk space.

### Q71: How does the Datadog Agent access container logs?
**A71:** By mounting the host node's log directories directly into the Agent container using `hostPath` volumes.
```yaml
volumeMounts:
  - name: podlogdir
    mountPath: /var/log/pods
```

### Q72: What is APM (Application Performance Monitoring)?
**A72:** A Datadog service that tracks individual transaction traces, database query runtimes, and execution errors across your microservices, helping developers locate latency bottlenecks.

### Q73: How do you configure a Backend pod to send traces to the Datadog Agent?
**A73:** By setting environment variables directing the APM tracer to send spans to the parent node's IP address.
```yaml
env:
  - name: DD_AGENT_HOST
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
```

### Q74: What is DogStatsD?
**A74:** A metrics aggregation service bundled inside the Datadog Agent. It accepts custom metrics sent from your application code over UDP (Port 8125).

### Q75: How do you define custom service names and environments in Datadog?
**A75:** Using the standard unified service tagging environment variables: `DD_ENV`, `DD_SERVICE`, and `DD_VERSION`.

### Q76: What annotation tells Datadog to parse container logs as Node.js JSON?
**A76:** Pod log annotations define the parser source and service name mapping.
```yaml
annotations:
  ad.datadoghq.com/app.logs: '[{"source": "nodejs", "service": "prosper-be"}]'
```

### Q77: What is Datadog Autodiscovery?
**A77:** An agent feature that automatically detects running containers (e.g., Redis) and configures the matching integration check to scrape metrics without manual configuration.

### Q78: Why are system metrics like CPU/Memory utilization collected by Datadog?
**A78:** To monitor EKS resource allocation, set alerts on node saturation, and optimize cluster capacity planning.

### Q79: What is synthetic monitoring in Datadog?
**A79:** An automated testing system where Datadog servers periodically ping your public endpoints (e.g., `https://prosper.lawyered.in`) from globally distributed regions to test availability.

### Q80: How does Datadog trace database queries without installing agents on RDS?
**A80:** By combining APM trace spans from the EKS backend code with Database Monitoring (DBM) metrics scraped from the RDS engine via the AWS IAM integration.

### Q81: What are Datadog log pipelines?
**A81:** Pipelines in the Datadog Cloud UI that parse, clean, filter, and extract attributes from raw string logs, transforming them into searchable dashboard facets.

### Q82: What is log volume indexing control?
**A82:** A cost-control feature in Datadog allowing you to decide what percentage of logs are indexed for search vs what percentage are archived directly to S3.

### Q83: What is tracing propagation?
**A83:** The process where HTTP headers (e.g., `x-datadog-trace-id`) are passed from the Frontend app to the Backend API, allowing Datadog to stitch the entire request journey together.

### Q84: What is a Datadog monitor?
**A84:** An alerting rule that triggers Slack notifications or PagerDuty calls when a metric (e.g., HTTP 5xx error rate) exceeds a defined threshold for X minutes.

### Q85: What is host-port mapping for DogStatsD?
**A85:** Exposing Port 8125 on the EKS node IP so that containers using host networking can stream UDP metrics directly to the Datadog daemon.

---

## 🛠️ Category 6: Infrastructure & IAC (Q86 - Q100)

### Q86: What does the EKS module do in our Terraform configuration?
**A86:** It automates EKS cluster creation, setting up control plane security groups, OIDC providers, KMS keys, node groups, and IAM role mapping.

### Q87: Why do we use Helm releases in Terraform?
**A87:** It allows us to manage Kubernetes-native application packages (like `aws-load-balancer-controller` or `datadog-agent`) directly inside our infrastructure-as-code repository.

### Q88: What is a Terraform `Moved` block?
**A88:** A declarative block used to rename or move resources in your state file without destroying and recreating them, preventing downtime during refactoring.
```hcl
moved {
  from = aws_secretsmanager_secret.old_secret
  to   = aws_secretsmanager_secret.new_secret
}
```

### Q89: What is `state locking` in Terraform?
**A89:** A mechanism (usually using a DynamoDB table) that prevents two developers from running `terraform apply` concurrently, protecting the state file from corruption.

### Q90: How do you handle database credentials securely inside Terraform?
**A90:** By utilizing `random_password` resources to generate strong passwords and storing them directly in AWS Secrets Manager without hardcoding values in variables.

### Q91: What is a target group deregistration delay?
**A91:** The period (e.g., 30 seconds) during which an ALB stops sending new requests to an EKS pod being terminated, allowing active transactions to finish gracefully.

### Q92: How do you verify an Ingress has successfully reconciled in EKS?
**A92:** By running `kubectl get ingress -A` and verifying the `ADDRESS` column is populated with the ALB host address.

### Q93: How do you view the controller logs to debug a failed ALB creation?
**A93:** Run the following command:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
```

### Q94: Why would a pod get stuck in a `Pending` state?
**A94:** Usually due to resource starvation (insufficient CPU/Memory on nodes to satisfy the pod's `requests`), or strict Node taints/tolerations or affinity rules.

### Q95: Why would a pod get stuck in `CrashLoopBackOff`?
**A95:** The container starts but immediately crashes. Common causes include missing database environment variables, incorrect database connection URLs, or code errors.

### Q96: What is a `502 Bad Gateway` error on an Ingress domain?
**A96:** The ALB is healthy, but it cannot connect to the backend EKS pods. This occurs if EKS pods are crashing, target port configuration in the Ingress does not match the actual container port, or security groups are misconfigured.

### Q97: What is a `504 Gateway Timeout` error?
**A97:** The EKS pod accepted the request but failed to respond within the ALB's timeout limit (default 60 seconds), usually due to database locking, deadlocks, or external API timeouts.

### Q98: How do you view live logs of a running Backend pod?
**A98:** Run the following command:
```bash
kubectl logs -n prod -l app=prod-lawyered-be -f --tail=100
```

### Q99: How do you inspect the history of an Ingress resource to find errors?
**A99:** Run the following command and inspect the `Events` section:
```bash
kubectl describe ingress argocd-ingress -n argo-cd
```

### Q100: How do you check which pods are consuming the most CPU/Memory inside a namespace?
**A100:** Run the following command:
```bash
kubectl top pods -n prod
```
