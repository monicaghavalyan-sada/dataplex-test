# Dataplex Quality Scan Automation

This project automates data quality monitoring in Google Cloud Dataplex using Terraform and GitHub Actions. Instead of manually managing scans through the console, you define quality rules in YAML files and push them to GitHub. The system handles the rest - creating new scans, updating existing ones, or recreating them when necessary.

The infrastructure is fully codified in Terraform, and authentication uses Workload Identity Federation (no service account keys needed). The workflow is smart enough to preserve scan history when possible by only recreating scans when the data source changes.

---

## Architecture

```
                    GitHub Repository
         ┌──────────────────────────────────────┐
         │                                      │
         │  quality-scan-yamls/                 │
         │    ├── scan-1/                       │
         │    │   ├── config.yaml               │
         │    │   └── rules.yaml                │
         │    └── scan-2/                       │
         │        ├── config.yaml               │
         │        └── rules.yaml                │
         │                                      │
         └───────────────┬──────────────────────┘
                         │
                    Push to main
                         │
                         ▼
              ┌─────────────────────┐
              │  GitHub Actions     │
              │                     │
              │  1. Authenticate    │
              │     via WIF         │
              │                     │
              │  2. Process YAMLs   │
              │     Upload to GCS   │
              │                     │
              └──────────┬──────────┘
                         │
                         ▼
         ┌──────────────────────────────────────┐
         │     Google Cloud Platform            │
         │                                      │
         │  ┌──────────────┐   ┌──────────────┐ │
         │  │  Workload    │──▶│   Service    │ │
         │  │  Identity    │   │   Account    │ │
         │  │  Federation  │   │ github-sa    │ │
         │  └──────────────┘   └──────┬───────┘ │
         │                            │         │
         │           ┌────────────────┘         │
         │           ▼                          │
         │  ┌──────────────────────────────┐    │
         │  │      Dataplex Lake           │    │
         │  │                              │    │
         │  │   Data Quality Scans:        │    │
         │  │     • scan-1-scan            │    │
         │  │     • scan-2-scan            │    │
         │  │                              │    │
         │  └──────────────────────────────┘    │
         │                                      │
         │  ┌─────────────┐  ┌────────────────┐ │
         │  │ GCS Bucket  │  │    BigQuery    │ │
         │  │             │  │                │ │
         │  │ • configs   │  │ • Source data  │ │
         │  │ • backups   │  │ • Scan results │ │
         │  └─────────────┘  └────────────────┘ │
         │                                      │
         └──────────────────────────────────────┘
```

The flow is straightforward: you push YAML changes to GitHub, which triggers the workflow. The workflow authenticates to GCP, processes your configuration files, uploads them to GCS, and then either creates new scans or updates existing ones based on what changed.

---

## Project Structure

```
dataplex-test/
├── .github/
│   ├── scripts/
│   │   └── process-scan-config.sh          # Validates and parses configs
│   └── workflows/
│       └── update-quality-scans.yml        # Main CI/CD workflow
│
├── quality-scan-yamls/                      # One folder per scan
│   ├── consistency-checks/
│   │   ├── config.yaml                     # Dataset, table, schedule
│   │   └── rules.yaml                      # Quality checks
│   └── validity-checks/
│       ├── config.yaml
│       └── rules.yaml
│
└── terraform/                               # Infrastructure as Code
    ├── provider.tf                         # Terraform configuration
    ├── variables.tf & terraform.tfvars     # Configuration
    ├── storage.tf                          # GCS bucket
    ├── bigquery.tf                         # BigQuery datasets
    ├── dataplex_lake.tf & dataplex_asset.tf # Dataplex resources
    ├── iam.tf                              # Service accounts
    ├── workload_identity.tf                # WIF setup
    └── outputs.tf                          # Terraform outputs
```

Each scan lives in its own folder under `quality-scan-yamls/`. The folder contains two files: `config.yaml` defines which table to monitor and when, while `rules.yaml` defines what quality checks to run.

---

## Infrastructure Components

The Terraform configuration creates everything needed to run automated quality scans. Here's what gets deployed:

**Storage and Data:**
The system creates a GCS bucket to store configuration files and backups, plus a BigQuery dataset for scan results. The Dataplex configuration includes a lake (top-level container), a zone (logical grouping), and an asset pointing to your source BigQuery table.

**Service Accounts:**
Two service accounts are created. The `dataplex-sa` is used by Dataplex for operations. The `github-actions-sa` is what your GitHub workflow uses, with permissions to upload to GCS, manage Dataplex scans, and read BigQuery tables.

**Workload Identity Federation:**
Instead of using static service account keys, WIF allows GitHub Actions to authenticate using OIDC tokens. GitHub generates a temporary token, exchanges it with the Workload Identity Pool, and gets credentials to impersonate the service account. These credentials are short-lived and automatically rotated.

---

## Configuration Files

Each scan requires two YAML files:

### config.yaml

This defines scan parameters that are immutable in Dataplex. Changing these requires recreating the scan.

```yaml
dataset: sentiment_analysis          # BigQuery dataset
table: product_sentiment_summary     # BigQuery table
schedule: "0 2 * * *"               # Cron schedule (2 AM daily)
description: "Daily quality scan"    # Scan description
display_name: "Product Quality"      # Display name
```

### rules.yaml

This defines the quality checks to run. These can be updated without recreating the scan.

```yaml
rules:
  - nonNullExpectation: {}          # Check for null values
    column: product_id
    dimension: COMPLETENESS
    threshold: 1.0                  # 100% of rows must pass
  
  - rangeExpectation:               # Check value range
      minValue: '0'
      maxValue: '100'
    column: score_pct
    dimension: VALIDITY
    threshold: 0.95                 # 95% of rows must pass
```

The threshold determines what percentage of rows must pass each check. Setting it to 1.0 means every row must pass. Setting it to 0.95 allows up to 5% of rows to fail the check.

---

## How the Workflow Works

When you push changes to `quality-scan-yamls/**/*.yaml`, GitHub Actions triggers the workflow. Here's what happens:

**Step 1: Authentication**
The workflow uses Workload Identity Federation to authenticate. GitHub generates an OIDC token, exchanges it with the WIF Pool, and impersonates the `github-actions-sa` service account.

**Step 2: Change Detection**
The workflow uses `git diff` to find which folders have changed files. It processes each changed folder independently.

**Step 3: Processing Each Folder**
For each folder, the helper script validates YAML syntax, extracts configuration values, and uploads files to GCS. Both current files and timestamped backups are stored.

**Step 4: Smart Update Decision**
The workflow checks if a scan with this name already exists. If it does, it retrieves the current data source and compares it with the new configuration.

```
┌─────────────────────────────────────┐
│ Data source changed?                │
│ (dataset or table different)        │
└──────────┬──────────────┬───────────┘
           │              │
       YES │              │ NO
           │              │
           ▼              ▼
┌──────────────┐  ┌──────────────┐
│ DELETE scan  │  │ UPDATE scan  │
│ Wait 120s    │  │ (new rules)  │
│ CREATE scan  │  │              │
└──────────────┘  └──────────────┘
```

If only the rules changed, the scan is updated in place, preserving its history. If the data source changed, the scan must be deleted and recreated because that parameter is immutable.

**Step 5: Execution**
The workflow runs the appropriate `gcloud` commands to update or recreate the scan, then logs the results.

---

## Setup

You'll need Terraform v1.13.4, the gcloud CLI, and a GCP project with billing enabled. Your account needs permissions to create service accounts, manage IAM, and create Dataplex resources.

**Configure Terraform:**
Edit `terraform/terraform.tfvars` with your project details:

```hcl
project_id      = "your-gcp-project-id"
region          = "us-central1"
source_dataset  = "sentiment_analysis"
source_table    = "product_sentiment_summary"
```

**Deploy Infrastructure:**

```bash
cd terraform
terraform init
terraform apply
```

After deployment completes, get the values needed for GitHub:

```bash
terraform output github_actions_config
```

**Configure GitHub:**
In your repository, go to Settings → Secrets and variables → Actions.

Add these **Secrets:**
- `WORKLOAD_IDENTITY_PROVIDER` - Copy from Terraform output
- `SERVICE_ACCOUNT` - Copy from Terraform output

Add these **Variables:**
- `GCP_PROJECT_ID` - Your project ID
- `GCP_REGION` - us-central1
- `BUCKET_NAME` - Copy from Terraform output

**Test the Setup:**

```bash
echo "# test" >> quality-scan-yamls/consistency-checks/rules.yaml
git add .
git commit -m "Test workflow"
git push origin main
```

Watch the Actions tab to see the workflow run.

---

## Daily Usage

**Adding a New Scan:**

```bash
mkdir quality-scan-yamls/customer-quality
# Create config.yaml and rules.yaml
git add quality-scan-yamls/customer-quality/
git commit -m "Add customer quality scan"
git push
```

The folder name is used directly as the scan name and must contain only lowercase/uppercase letters, numbers, and hyphens. If the folder name doesn't meet these requirements, the workflow will fail.

**Updating Rules:**
Edit `rules.yaml` to adjust thresholds or add checks, then push. The scan updates without losing history.

**Changing Data Source:**
Edit `config.yaml` to change the dataset or table. The scan gets deleted and recreated. This is slower but necessary since data source is immutable.

