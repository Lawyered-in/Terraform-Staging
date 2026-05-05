# -------------------------------------------------------------------
# IAM Role for VPC CNI — IRSA (IAM Roles for Service Accounts)
# -------------------------------------------------------------------
locals {
  oidc_id = replace(var.oidc_provider_url, "https://", "")
}

resource "aws_iam_role" "vpc_cni" {
  name = "${var.cluster_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${local.oidc_id}:sub" : "system:serviceaccount:kube-system:aws-node",
            "${local.oidc_id}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge({ Name = "${var.cluster_name}-vpc-cni-role" }, var.tags)
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# -------------------------------------------------------------------
# IAM Role for EBS CSI — IRSA
# -------------------------------------------------------------------
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = { Federated = var.oidc_provider_arn }
        Condition = {
          StringEquals = {
            "${local.oidc_id}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa",
            "${local.oidc_id}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge({ Name = "${var.cluster_name}-ebs-csi-role" }, var.tags)
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# -------------------------------------------------------------------
# EKS Addons
# -------------------------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = var.cluster_name
  addon_name               = "vpc-cni"
  addon_version            = var.addon_versions["vpc-cni"]
  service_account_role_arn = aws_iam_role.vpc_cni.arn
  tags                     = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name = var.cluster_name
  addon_name   = "coredns"
  addon_version = var.addon_versions["coredns"]
  tags         = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = var.cluster_name
  addon_name   = "kube-proxy"
  addon_version = var.addon_versions["kube-proxy"]
  tags         = var.tags
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name = var.cluster_name
  addon_name   = "metrics-server"
  addon_version = var.addon_versions["metrics-server"]
  tags         = var.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.addon_versions["aws-ebs-csi-driver"]
  service_account_role_arn = aws_iam_role.ebs_csi.arn
  tags                     = var.tags
}
