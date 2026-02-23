#!/bin/bash
# cleanup-manual-pvs.sh
#
# Remove manual PersistentVolumes created for Spark testing.
#
# This script cleans up PVs created by setup-manual-pvs.sh.
# It will delete PVs and clean up storage directories in minikube.
#
# Usage:
#   ./scripts/testing/cleanup-manual-pvs.sh [storage_base]
#
# Arguments:
#   storage_base Base path for storage (default: /tmp/spark-testing)
#
# Warning: This will delete all data in the PVs!
#
# Related: issue-001, WS-TESTING-001, WS-TESTING-002

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
STORAGE_BASE=${1:-/tmp/spark-testing}

# Validate minikube is running
if ! minikube status &>/dev/null; then
    echo -e "${RED}Error: minikube is not running${NC}"
    exit 1
fi

echo -e "${YELLOW}=== Spark Testing: Manual PV Cleanup ===${NC}"
echo "Storage base: $STORAGE_BASE"
echo -e "${RED}Warning: This will delete all data in the PVs!${NC}"
echo ""

# Confirm deletion
read -p "Are you sure? (yes/no): " -n 3 -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Step 1: Delete PVs
echo -e "${YELLOW}Step 1: Deleting PVs...${NC}"
kubectl delete pv minio-pv data-postgresql-metastore-41-0 postgresql-pv --ignore-not-found=true
echo -e "${GREEN}✓ PVs deleted${NC}"
echo ""

# Step 2: Clean up directories in minikube
echo -e "${YELLOW}Step 2: Cleaning up storage directories...${NC}"
minikube ssh "sudo rm -rf $STORAGE_BASE/minio $STORAGE_BASE/postgresql" || {
    echo -e "${YELLOW}⚠ Failed to clean directories (may not exist)${NC}"
}
echo -e "${GREEN}✓ Directories cleaned${NC}"
echo ""

# Step 3: Verify cleanup
echo -e "${YELLOW}Step 3: Verifying cleanup...${NC}"
REMAINING=$(kubectl get pv -o name | grep -E "minio-pv|data-postgresql-metastore-41-0|postgresql-pv" || true)
if [ -z "$REMAINING" ]; then
    echo -e "${GREEN}✓ All PVs removed successfully${NC}"
else
    echo -e "${YELLOW}⚠ Some PVs still exist:${NC}"
    echo "$REMAINING"
fi
echo ""

echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo "You can now re-run setup-manual-pvs.sh if needed."
