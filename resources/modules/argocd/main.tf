# -------------------------------------------------------------------
# Argo CD — Helm Release
# -------------------------------------------------------------------
resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  namespace        = "argo-cd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.5.2"

  values = [
    file("${path.module}/helm/argocd-values.yaml")
  ]
}
