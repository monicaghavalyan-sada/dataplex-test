#!/bin/bash
set -e

FOLDER=$1
BUCKET_NAME=$2

if [ -z "$FOLDER" ] || [ -z "$BUCKET_NAME" ]; then
  echo "Usage: $0 <folder_path> <bucket_name>"
  exit 1
fi

FOLDER_NAME=$(basename "$FOLDER")
SCAN_NAME=$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g;s/-\+/-/g;s/^-//;s/-$//')-scan

echo "Processing folder: $FOLDER_NAME -> $SCAN_NAME"

# Validate files exist
if [ ! -f "$FOLDER/config.yaml" ] || [ ! -f "$FOLDER/rules.yaml" ]; then
  echo "ERROR: Missing config.yaml or rules.yaml in $FOLDER"
  exit 1
fi

# Validate and extract all config values in one Python call
CONFIG_VALUES=$(python3 << 'EOF'
import yaml
import sys

try:
    with open(sys.argv[1] + '/config.yaml') as cf, open(sys.argv[1] + '/rules.yaml') as rf:
        config = yaml.safe_load(cf)
        yaml.safe_load(rf)
        print(f"{config['dataset']}|{config['table']}|{config['schedule']}|{config['description']}|{config['display_name']}")
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF
"$FOLDER")

[ $? -ne 0 ] && exit 1

IFS='|' read -r DATASET TABLE SCHEDULE DESCRIPTION DISPLAY_NAME <<< "$CONFIG_VALUES"

# Upload files to GCS
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
GCS_PATH="gs://${BUCKET_NAME}/quality-scan-yamls/${FOLDER_NAME}"

# Upload files efficiently
for file in rules.yaml config.yaml; do
  gsutil cp "$FOLDER/$file" "$GCS_PATH/$file"
  gsutil cp "$FOLDER/$file" "$GCS_PATH/backups/${file%.yaml}_${TIMESTAMP}.yaml"
done

# Output variables for main workflow
echo "SCAN_NAME=$SCAN_NAME"
echo "DATASET=$DATASET"
echo "TABLE=$TABLE"
echo "SCHEDULE=$SCHEDULE"
echo "DESCRIPTION=$DESCRIPTION"
echo "DISPLAY_NAME=$DISPLAY_NAME"
echo "GCS_PATH=$GCS_PATH"