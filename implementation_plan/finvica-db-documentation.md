# 📊 Finvica Database Documentation

This document provides a detailed overview of the PostgreSQL RDS instance provisioned for the **Finvica** application in the staging environment.

## 🗄️ Database Overview

| Attribute | Value |
|-----------|-------|
| **Application** | Finvica |
| **Environment** | Staging (`stg`) |
| **Engine Type** | PostgreSQL |
| **Engine Version** | `18.3` |
| **Instance Class** | `db.t4g.medium` |
| **Storage Size** | 30 GB (Initial) |
| **Autoscaling** | Up to 500 GB |
| **Storage Type** | GP3 (General Purpose SSD) |

## 🛠️ Configuration Details

### 1. RDS Parameter Group
- **Name**: `finvica-db-parameter-group`
- **Family**: `postgres18`
- **Purpose**: Allows for custom database tuning and parameter overrides specific to the Finvica workload.

### 2. Networking & Security
- **VPC**: `stg-mb-vpc01`
- **Subnets**: Deployed across private database subnets for high security (no public access).
- **Multi-AZ**: Disabled (Single AZ for cost optimization in staging).
- **Security Group**: Automatically created with inbound rules restricted to the application layer.

### 3. Identity & Access Management
- **Master Username**: `dbadmin` (changed from `admin` to avoid reserved word conflict)
- **Password Management**: The master password is not stored in plain text. It is managed via **AWS Secrets Manager**.
- **Secret Name**: `finvica-db-secrets`
- **Usage in Code**: Terraform pulls the secret value dynamically during deployment to avoid leakage.

## 📂 Infrastructure Code Reference

The database is defined within the `rds_instances` map in `terraform.tfvars`:

```hcl
  finvica = {
    engine                = "postgres"
    engine_version        = "18.2-R1"            
    instance_class        = "db.t4g.medium"      
    allocated_storage     = 30                   
    max_allocated_storage = 500                  
    db_name               = "finvica"            
    username              = "admin"              
    password              = "77@fInViCa@88#Secure" 
    vpc_key               = "stg-mb-vpc01"       
    subnet_keys           = ["stg-mb-database-subnet01", "stg-mb-database-subnet02", "stg-mb-database-subnet03"]
    multi_az              = false                
    skip_final_snapshot   = true                 
    parameter_group_name  = "finvica-dv-parameter-group" 
    parameter_group_family = "postgres16"          
    tags = {
      Environment = "staging"
      Project     = "finvica"
      Role        = "database-rds"
    }
  }
```

## 🔄 Deployment Status
- **Terraform Module**: `rds` module (v1.0.0 enhanced with parameter group support).
- **Automation**: Managed via root `main.tf` orchestration.
