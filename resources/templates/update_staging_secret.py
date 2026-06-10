import json
import subprocess

secret_id = "staging/admin-lawyered"

print("Fetching secret value...")
result = subprocess.run(
    ["aws", "secretsmanager", "get-secret-value", "--secret-id", secret_id, "--query", "SecretString", "--output", "text"],
    capture_output=True,
    text=True
)

if result.returncode != 0:
    print("Error fetching secret:", result.stderr)
    exit(1)

secret_data = json.loads(result.stdout.strip())

# Update the non-production database credentials
secret_data["DATABASE_URL"] = "mysql://admin:giD8%3Ap34U7Ijfo%236.WC~3DK%24mh-l@lawyered-database-instance-1.cj446ammul0i.ap-south-1.rds.amazonaws.com:3306/lawyered_db"
secret_data["DB_NAME"] = "lawyered_db"
secret_data["DB_USERNAME"] = "admin"
secret_data["DB_PASSWORD"] = "giD8:p34U7Ijfo#6.WC~3DK$mh-l"

updated_secret_string = json.dumps(secret_data, indent=2)

print("Updating secret in AWS Secrets Manager...")
update_result = subprocess.run(
    ["aws", "secretsmanager", "put-secret-value", "--secret-id", secret_id, "--secret-string", updated_secret_string],
    capture_output=True,
    text=True
)

if update_result.returncode != 0:
    print("Error updating secret:", update_result.stderr)
    exit(1)

print("Staging secret updated successfully!")
