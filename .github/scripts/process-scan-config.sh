#!/bin/bash
set -e

FOLDER="$1"
BUCKET_NAME="$2"

if [ -z "$FOLDER" ] || [ -z "$BUCKET_NAME" ]; then
  echo "ERROR: Usage: $0 <folder_path> <bucket_name>" >&2
  exit 1
fi

FOLDER_NAME=$(basename "$FOLDER")

echo "Processing folder: $FOLDER_NAME" >&2

# Validate scan name format
if ! [[ "$FOLDER_NAME" =~ ^[a-z0-9-]+$ ]]; then
  echo "ERROR: Invalid folder name '$FOLDER_NAME' - must contain only lowercase letters, numbers, and hyphens" >&2
  exit 1
fi

# Validate files exist
if [ ! -f "$FOLDER/config.yaml" ] || [ ! -f "$FOLDER/rules.yaml" ]; then
  echo "ERROR: Missing config.yaml or rules.yaml in $FOLDER" >&2
  exit 1
fi

# Validate and extract all config values in a Python call
CONFIG_VALUES=$(python3 -c "
import yaml
import sys

try:
    with open('$FOLDER/config.yaml') as cf, open('$FOLDER/rules.yaml') as rf:
        config = yaml.safe_load(cf)
        yaml.safe_load(rf)
        print(f\"{config['dataset']}|{config['table']}|{config['schedule']}|{config['description']}|{config['display_name']}\")
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
")

if [ $? -ne 0 ]; then
  exit 1
fi

IFS='|' read -r DATASET TABLE SCHEDULE DESCRIPTION DISPLAY_NAME <<< "$CONFIG_VALUES"

# Upload files to GCS
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
GCS_PATH="gs://${BUCKET_NAME}/quality-scan-yamls/${FOLDER_NAME}"

# Upload files efficiently
for file in rules.yaml config.yaml; do
  gsutil cp "$FOLDER/$file" "$GCS_PATH/$file"
  gsutil cp "$FOLDER/$file" "$GCS_PATH/backups/${file%.yaml}_${TIMESTAMP}.yaml"
done

# Output variables for main workflow (stdout only, no directory paths)
echo "SCAN_NAME=\"$FOLDER_NAME\""
echo "DATASET=\"$DATASET\""
echo "TABLE=\"$TABLE\""
echo "SCHEDULE=\"$SCHEDULE\""
echo "DESCRIPTION=\"$DESCRIPTION\""
echo "DISPLAY_NAME=\"$DISPLAY_NAME\""
echo "GCS_PATH=\"$GCS_PATH\""
