# Walkthrough: Infrastructure Update

I have successfully provisioned the new PostgreSQL database and removed the Redis standalone module as requested.

## Changes Made

### 1. PostgreSQL RDS Provisioning
- **Instance Name**: `core-uat-db`
- **Engine**: PostgreSQL 15
- **Endpoint**: `core-uat-db.cj446ammul0i.ap-south-1.rds.amazonaws.com:5432`
- **Username**: `dbadmin`
- **Storage**: 30GB (gp3) with auto-scaling enabled up to 500GB.
- **Security**: Placed in the existing database subnets with a dedicated security group.

### 2. Redis Removal
- **Module Deleted**: Removed `resources/modules/redis/` directory.
- **Code Cleaned**: Removed the `module "redis_box"` call from `templates/main.tf`.
- **Resources Destroyed**: The standalone Redis Helm release has been removed from the EKS cluster.

## Troubleshooting & Stability
During the process, we encountered transient EKS API timeouts caused by the EKS node group scaling down from **4 to 1 node**. 

> [!NOTE]
> The infrastructure is now stable, and the database is fully functional. The next `terraform apply` will be a no-op refresh.

## Verification
- [x] RDS Instance Created & Available.
- [x] Redis Module & Resources Removed.
- [x] Terraform State Synchronized.
