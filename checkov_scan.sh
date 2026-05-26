#!/bin/bash
# Set variables
TERRAFORM_CODE_DIR="./"                   # Directory containing Terraform files
CHECKOV_OUTPUT_FILE="checkov_output.json"  # File to save Checkov scan output
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/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"
# Run Checkov scan
checkov -d "$TERRAFORM_CODE_DIR" -o cli > "$CHECKOV_OUTPUT_FILE"
if [ $? -ne 0 ]; then
  echo "Checkov scan failed."
  exit 0
fi
# Parse Checkov output for critical and high vulnerabilities
critical_issues=$(jq '.results.failed_checks | map(select(.severity == "CRITICAL")) | length' "$CHECKOV_OUTPUT_FILE")
high_issues=$(jq '.results.failed_checks | map(select(.severity == "HIGH")) | length' "$CHECKOV_OUTPUT_FILE")
# Check if critical or high vulnerabilities were found
if [ "$critical_issues" -gt 0 ] || [ "$high_issues" -gt 0 ]; then
  message="Critical ($critical_issues) or high ($high_issues) vulnerabilities found in the Checkov scan."
  # Send alert to Slack for critical/high issues
  curl --ssl-no-revoke -X POST --data-urlencode \
    "payload={\"channel\": \"#16th-sep-automated-capstone-project\", \"username\": \"ACP-TEAM\", \"text\": \"$message\", \"icon_emoji\": \":ghost:\"}" \
    $SLACK_WEBHOOK_URL
  exit 0  # Exit with failure since critical/high issues were found
else
  # No critical or high vulnerabilities found, send summary
  summary="No critical or high vulnerabilities found in the latest Checkov scan."
  echo "$summary"
  curl --ssl-no-revoke -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"$summary\"}" \
    $SLACK_WEBHOOK_URL
  exit 0
fi
 