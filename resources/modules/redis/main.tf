# Redis Module - Main Configuration
# ---------------------------------

resource "helm_release" "redis" {
  # Name of the Helm release in the cluster.
  name = var.release_name

  # Official Bitnami repository for the Redis chart.
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"

  # Deploying into the 'stg' namespace.
  namespace = var.namespace

  # Automatically create the namespace if it does not exist.
  create_namespace = true

  # Load the values from the redis.yaml file we created.
  values = [
    file("${path.module}/redis.yaml")
  ]

  # Wait for all resources to be ready before finishing the apply.
  wait = true
}
