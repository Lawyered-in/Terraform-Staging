# Core UAT Database Implementation Plan

This document outlines the plan to provision the new PostgreSQL RDS database `core-uat-db` based on your requirements, along with a cost estimation.

## User Review Required

> [!IMPORTANT]
> Please review the estimated costs and the proposed configuration below. If everything looks correct, please **approve this plan** so I can begin the implementation.

## Clarification Addressed
Based on your feedback, I have confirmed that `core-uat-db` will be a **Normal PostgreSQL RDS Instance** (NOT Aurora), but it will be deployed in the exact same VPC and database subnet group as your existing `lawyered-database`.

## Open Questions
1. **Multi-AZ Deployment**: Should this database be deployed in a Multi-AZ configuration for high availability? (I am assuming Single-AZ for now to keep costs lower for a UAT environment, but let me know if you need Multi-AZ).
2. **Master Username**: I plan to use `dbadmin` as the master username, and generate a secure password. Is this acceptable?

## Proposed Configuration

- **Instance Name**: `core-uat-db`
- **Engine**: Normal PostgreSQL (RDS)
- **Engine Version**: 15 (or the latest stable 14.x/15.x you prefer)
- **Instance Class**: `db.t4g.medium`
- **Allocated Storage**: 30 GB (gp3)
- **Max Allocated Storage**: 500 GB (Auto-scaling threshold)
- **Subnets**: Same database subnets used for `lawyered-database` (`stg-mb-database-subnet01`, `02`, `03`) inside `stg-mb-vpc01`.

## Cost Estimation (ap-south-1 / Mumbai Region)

> [!NOTE]
> The following is an approximate monthly cost estimation for a **Single-AZ** deployment of standard RDS PostgreSQL.

| Resource | Description | Estimated Monthly Cost |
| :--- | :--- | :--- |
| **Compute** | `db.t4g.medium` instance (~$0.076 / hour) | ~$55.00 |
| **Storage** | 30 GB of `gp3` storage (~$0.132 / GB-month) | ~$3.96 |
| **Data Transfer** | Inbound is free, outbound depends on usage | Variable |
| **Total Estimated Cost** | **Single-AZ Configuration** | **~$58.96 / month** |

*(If you require Multi-AZ, the compute and storage costs will double to approximately ~$117.92 / month).*

## Proposed Changes

### RDS Module Updates
We need to update the base RDS module to support storage auto-scaling since it currently doesn't accept the `max_allocated_storage` parameter.

#### [MODIFY] [variables.tf](file:///c:/Users/PavanSD/Downloads/resources/resources/modules/rds/variables.tf)
Add `max_allocated_storage` variable to the RDS module.

#### [MODIFY] [main.tf](file:///c:/Users/PavanSD/Downloads/resources/resources/modules/rds/main.tf)
Update the `aws_db_instance` resource to map the `max_allocated_storage` variable.

### Infrastructure Configuration Updates

#### [MODIFY] [variables.tf](file:///c:/Users/PavanSD/Downloads/resources/resources/templates/variables.tf)
Update the `rds_instances` variable type definition to allow `max_allocated_storage`.

#### [MODIFY] [terraform.tfvars](file:///c:/Users/PavanSD/Downloads/resources/resources/templates/terraform.tfvars)
Add the `core-uat-db` configuration block under `rds_instances`.

## Verification Plan
1. Run `terraform plan` to ensure the new database configuration is valid.
2. Run `terraform apply` to provision the database.
3. Verify the database endpoint is successfully generated and storage auto-scaling is enabled up to 500 GB.
