# External Secrets Configuration
# Supports: AWS, GCP, Azure, IBM cloud providers

externalSecrets:
  enabled: false

  # Provider: aws, gcp, azure, ibm
  provider: "aws"

  # AWS Secrets Manager
  region: "us-east-1"
  prefix: "spark"  # Prefix for secret keys
  aws:
    iamRole: "arn:aws:iam::123456789012:role/spark-secrets-role"

  # GCP Secret Manager
  project: "my-project"
  gcp:
    clusterLocation: "us-central1-a"
    clusterName: "spark-cluster"
    serviceAccountEmail: "spark-secrets@my-project.iam.gserviceaccount.com"

  # Azure Key Vault
  azure:
    tenantId: "12345678-1234-1234-1234-123456789012"
    clientId: "87654321-4321-4321-4321-210987654321"
    vaultName: "spark-kv"
    secretName: "s3-credentials"

  # IBM Cloud Secrets Manager
  ibm:
    serviceUrl: "https://us-south.secrets-manager.appdomain.cloud"

# SealedSecrets Configuration (git-native encryption)
sealedSecrets:
  enabled: false
  # Encrypted data (use kubeseal to encrypt)
  data:
    access-key: ""  # Base64 encrypted
    secret-key: ""  # Base64 encrypted

# Vault Configuration
vault:
  enabled: false
  address: "https://vault.example.com:8200"
  role: "spark-connect"
