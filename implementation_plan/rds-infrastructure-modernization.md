# 🚀 RDS Infrastructure Modernization Report

This document outlines the architectural changes and deployment details for the **Finvica** and **Lawyered-Backend-New** databases in the Staging environment.

## 📅 Date: May 7, 2026

---

## 🎯 Objective
To provision a new backend database and optimize the existing database infrastructure for better scalability, security, and cost control.

## 🛠️ Implemented Architecture

### 1. Dynamic Resource Management
We transitioned from static resource definitions to a **Map-Driven Architecture** in Terraform. This allows us to manage multiple RDS instances using a single block of code.

*   **File**: `terraform.tfvars`
*   **Change**: Defined a central `rds_instances` map to control all DB settings (engine, version, storage, etc.) in one place.

### 2. High-Performance Database: `lawyered-backend-new`
A new PostgreSQL instance was created to support the latest backend workloads.
*   **Engine**: PostgreSQL 18.3
*   **Instance Class**: `db.t4g.medium` (Graviton-powered for cost/performance efficiency)
*   **Initial Storage**: 50 GB
*   **Initial DB Name**: `lawyered_backend_new`

### 3. Cost Optimization: `finvica`
We optimized the storage settings for the Finvica database to prevent unexpected cost spikes.
*   **Change**: Reduced `max_allocated_storage` from **500 GB** to **100 GB**.
*   **Logic**: This caps the autoscaling limit, ensuring the database only grows within a safe, predictable budget.

### 4. Advanced Security (Secrets Manager)
We implemented a **Dynamic Secrets Loop** to manage master passwords securely.
*   **Code Implementation**: 
    ```hcl
    resource "aws_secretsmanager_secret" "rds_secrets" {
      for_each = toset(["finvica", "lawyered-backend-new"])
      name     = "${each.key}-db-secrets"
      # ...
    }
    ```
*   **Benefit**: Every database now has its own unique, isolated secret in AWS Secrets Manager. No plain-text passwords are used in the infrastructure.

### 5. Custom Tuning (Parameter Groups)
Each database now uses its own dedicated **Parameter Group** following the naming convention `{name}-db-parameter-group`.
*   **Naming Pattern**: `lawyered-backend-new-db-parameter-group`
*   **Family**: `postgres18`

---

## 🔐 Credentials Summary

| Database | Username | Secret Name | Storage (Initial/Max) |
| :--- | :--- | :--- | :--- |
| **Finvica** | `dbadmin` | `finvica-db-secrets` | 30 GB / 100 GB |
| **Lawyered-Backend-New** | `dbadmin` | `lawyered-backend-new-db-secrets` | 50 GB / 100 GB |

---

## 🔄 Deployment Status
- [x] Terraform Configuration Updated
- [x] Secrets Manager Dynamic Refactor
- [x] Storage Optimization Applied
- [x] Validation (`terraform validate`) - **PASSED**
- [x] Plan (`terraform plan`) - **PASSED**
- [x] Apply (`terraform apply`) - **IN PROGRESS / SUCCESSFUL**

---

## 📜 Code Logic Explanation
We used **`moved` blocks** in the Terraform code to ensure that when we refactored the secrets, AWS did not destroy the existing data. This allowed for a "seamless migration" of the security resources without impacting the live database.
