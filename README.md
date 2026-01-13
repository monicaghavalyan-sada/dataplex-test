# Dataplex Quality Scan Automation

This project automates data quality monitoring in Google Cloud Dataplex using Terraform and GitHub Actions. Instead of manually managing scans through the console, you define quality rules in YAML files and push them to GitHub. The system handles the rest - creating new scans, updating existing ones, or recreating them when necessary.

The infrastructure is fully codified in Terraform, and authentication uses Workload Identity Federation (no service account keys needed). The workflow is smart enough to preserve scan history when possible by only recreating scans when the data source changes.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                        │
│  ┌────────────────────┐              ┌─────────────────────┐   │
│  │ quality-scan-yamls/│              │  GitHub Actions     │   │
│  │  ├── scan-1/       │   Push to    │  ┌───────────────┐ │   │
│  │  │  ├── config.yaml├──────main───►│  │ Authenticate  │ │   │
│  │  │  └── rules.yaml │              │  │  via WIF      │ │   │
│  │  └── scan-2/       │              │  └───────┬───────┘ │   │
│  │     ├── config.yaml│              │          │         │   │
│  │     └── rules.yaml │              │  ┌───────▼───────┐ │   │
│  └────────────────────┘              │  │ Process YAMLs │ │   │
│                                       │  │ Upload to GCS │ │   │
│                                       │  └───────┬───────┘ │   │
└───────────────────────────────────────────────┬─────────────────┘
                                                │
                    ┌───────────────────────────▼────────────────────┐
                    │         Google Cloud Platform                  │
                    │                                                │
                    │  ┌─────────────┐  ┌──────────────────────┐   │
                    │  │ Workload    │  │  Service Account     │   │
                    │  │ Identity    ├─►│  github-actions-sa   │   │
                    │  │ Federation  │  └──────────┬───────────┘   │
                    │  └─────────────┘             │               │
                    │                               │               │
                    │  ┌────────────────────────────▼─────────┐    │
                    │  │         Dataplex Lake               │    │
                    │  │  ┌──────────────────────────────┐   │    │
                    │  │  │   Data Quality Scans         │   │    │
                    │  │  │   ├── scan-1-scan           │   │    │
                    │  │  │   └── scan-2-scan           │   │    │
                    │  │  └──────────────────────────────┘   │    │
                    │  └──────────────────────────────────────┘    │
                    │                                                │
                    │  ┌─────────────┐  ┌─────────────────────┐   │
                    │  │ GCS Bucket  │  │  BigQuery Datasets  │   │
                    │  │ (configs +  │  │  ├── Source data    │   │
                    │  │  backups)   │  │  └── Scan results   │   │
                    │  └─────────────┘  └─────────────────────┘   │
                    └────────────────────────────────────────────────┘
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

The folder name gets sanitized to create the scan name (lowercase, special characters become hyphens, `-scan` suffix added).

**Updating Rules:**
Edit `rules.yaml` to adjust thresholds or add checks, then push. The scan updates without losing history.

**Changing Data Source:**
Edit `config.yaml` to change the dataset or table. The scan gets deleted and recreated. This is slower but necessary since data source is immutable.

---

## Understanding the Smart Update Logic

The workflow's decision about whether to update or recreate is based on Dataplex's constraints. The data source (which BigQuery table to monitor) cannot be changed on an existing scan. If you try, the API rejects it. The only way is to delete the scan and create a new one.

However, the quality rules are mutable. You can update them freely, and future scan runs will use the new rules. The workflow takes advantage of this by checking what changed. If only rules changed, it does a fast update. If the data source changed, it does the delete-and-recreate process.

This matters because deleting a scan loses its job history. The workflow tries to preserve scans whenever possible to keep that history intact.

---

## Workload Identity Federation Explained

Traditional authentication involves generating a service account key (JSON file) and storing it in GitHub Secrets. The problem is these keys are long-lived credentials. If someone accesses your secrets, they have full GCP access until you manually rotate the key.

Workload Identity Federation uses OIDC instead. When the workflow runs, GitHub generates a short-lived token with claims about the repository and workflow. This token is sent to GCP's Workload Identity Pool, which validates it's from GitHub and matches your allowed repository. The pool issues temporary GCP credentials (valid ~10 minutes) to impersonate your service account. When the workflow finishes, credentials expire automatically.

There's no key file to leak and no manual rotation needed. The workflow authenticates fresh every time it runs.

---

## Monitoring Results

**In the GCP Console:**
Navigate to Dataplex → Data Quality to see all scans. Click a scan to view its job history with pass/fail status and detailed results for each rule.

**In BigQuery:**
Query the results dataset for programmatic access or dashboards:

```sql
SELECT *
FROM `project.dataplex_scans.quality_scan_results`
WHERE scan_name = 'consistency-checks-scan'
ORDER BY job_start_time DESC
```

**Manual Trigger:**

```bash
gcloud dataplex datascans run scan-name \
  --location=us-central1 \
  --project=your-project-id
```

---

## Troubleshooting

**Authentication Failed:**
The WIF provider or service account values in GitHub don't match Terraform outputs. Run `terraform output` again and compare with your GitHub secrets character-by-character.

**Permission Denied:**
The service account is missing required roles. Run `terraform apply` to reapply IAM bindings.

**Workflow Not Triggering:**
Check that changed files are under `quality-scan-yamls/` with `.yaml` extension. The path filter is strict.

**Scan Shows INVALID:**
There's a YAML syntax error or issue with the rules. Check scan details in the console for the error message. Validate syntax locally:

```bash
python3 -c "import yaml; yaml.safe_load(open('rules.yaml'))"
```

---

## Backup System

Every time configs are uploaded, timestamped backups are created:

```
gs://bucket/quality-scan-yamls/scan-name/
  ├── config.yaml                    # Current version
  ├── rules.yaml                     # Current version
  └── backups/
      ├── config_20250113_120000.yaml
      ├── rules_20250113_120000.yaml
      └── ...
```

This creates an audit trail of all configuration changes. If a bad change breaks your scans, you can look at backups to see what changed and restore an old version.

---

## Best Practices

Start with lenient thresholds (0.7-0.8) and tighten them based on actual results. Setting thresholds too strict initially leads to constant false alarms instead of catching real issues.

Use descriptive folder names with lowercase and hyphens (`customer-quality-checks`). Avoid special characters since they get sanitized anyway.

For scan schedules, daily scans (`0 2 * * *`) work well for batch-loaded data. Hourly scans make sense for streaming tables, but remember each run costs money and reads your entire table.

Always commit `config.yaml` and `rules.yaml` together, and use descriptive commit messages that explain what changed and why.

---

## Support

For Dataplex and GCP questions, see the [Google Cloud Dataplex documentation](https://cloud.google.com/dataplex/docs) and [Workload Identity Federation docs](https://cloud.google.com/iam/docs/workload-identity-federation).

For questions about this implementation, open an issue in the repository.
