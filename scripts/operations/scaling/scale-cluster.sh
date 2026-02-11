#!/bin/bash
# Cluster Scaling Script
# Manually scales Kubernetes node pools for Spark workloads

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_TYPE="${CLUSTER_TYPE:-eks}"  # eks, aks, gke
REGION="${AWS_REGION:-${AZURE_REGION:-${GOOGLE_REGION:-us-east-1}}}"
CLUSTER_NAME="${CLUSTER_NAME:-spark-prod}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Manually scale cluster node pools.

OPTIONS:
    -c, --cluster NAME       Cluster name (default: spark-prod)
    -t, --type TYPE          Cluster type: eks|aks|gke (default: eks)
    -r, --region REGION      Cloud region (default: us-east-1)
    -n, --node-group NAME    Node group/pool name
    -s, --scale NUM          Desired node count
    -l, --list               List current node groups
    -h, --help               Show this help

EXAMPLES:
    $(basename "$0") --list
    $(basename "$0") --node-group spark-executors --scale 10
    $(basename "$0") -n spark-drivers -s 5 -t aks -r eastus
EOF
    exit 1
}

parse_args() {
    local action="scale"
    NODE_GROUP=""
    SCALE_COUNT=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--cluster)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            -t|--type)
                CLUSTER_TYPE="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -n|--node-group)
                NODE_GROUP="$2"
                shift 2
                ;;
            -s|--scale)
                SCALE_COUNT="$2"
                shift 2
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done

    if [[ "$action" == "list" ]]; then
        list_node_groups
        exit 0
    fi

    if [[ -z "$NODE_GROUP" ]] || [[ -z "$SCALE_COUNT" ]]; then
        echo "Error: --node-group and --scale are required for scaling"
        echo ""
        usage
    fi

    scale_node_group
}

list_node_groups() {
    echo "=== Node Groups for Cluster: $CLUSTER_NAME ==="
    echo ""

    case "$CLUSTER_TYPE" in
        eks)
            list_eks_node_groups
            ;;
        aks)
            list_aks_node_groups
            ;;
        gke)
            list_gke_node_groups
            ;;
        *)
            echo "Error: Unsupported cluster type: $CLUSTER_TYPE"
            exit 1
            ;;
    esac
}

list_eks_node_groups() {
    echo "Fetching EKS node groups..."
    aws eks list-nodegroups \
        --cluster-name "$CLUSTER_NAME" \
        --region "$REGION" \
        --query 'nodegroups' \
        --output text | while read -r ng; do
            aws eks describe-nodegroup \
                --cluster-name "$CLUSTER_NAME" \
                --nodegroup-name "$ng" \
                --region "$REGION" \
                --query 'nodegroup | {Name: nodegroupName, Status: status, Min: scalingConfig.minSize, Max: scalingConfig.maxSize, Current: scalingConfig.desiredSize, Instance: instanceTypes[0]}' \
                --output table
        done
}

list_aks_node_groups() {
    echo "Fetching AKS node pools..."
    az aks nodepool list \
        --resource-group "${CLUSTER_NAME}-rg" \
        --cluster-name "$CLUSTER_NAME" \
        --output table
}

list_gke_node_groups() {
    echo "Fetching GKE node pools..."
    gcloud container node-pools list \
        --cluster "$CLUSTER_NAME" \
        --region "$REGION" \
        --format="table(name,status,config.machineType,initialNodeCount,autoscaling.minNodeCount,autoscaling.maxNodeCount)"
}

scale_node_group() {
    echo "Scaling node group: $NODE_GROUP to $SCALE_COUNT nodes"
    echo "Cluster: $CLUSTER_NAME"
    echo "Type: $CLUSTER_TYPE"
    echo "Region: $REGION"
    echo ""

    case "$CLUSTER_TYPE" in
        eks)
            scale_eks_node_group
            ;;
        aks)
            scale_aks_node_group
            ;;
        gke)
            scale_gke_node_group
            ;;
        *)
            echo "Error: Unsupported cluster type: $CLUSTER_TYPE"
            exit 1
            ;;
    esac
}

scale_eks_node_group() {
    echo "Scaling EKS node group..."
    aws eks update-nodegroup-config \
        --cluster-name "$CLUSTER_NAME" \
        --nodegroup-name "$NODE_GROUP" \
        --scaling-config desiredSize="$SCALE_COUNT" \
        --region "$REGION" \
        --output table

    echo ""
    echo "Waiting for update to complete..."
    aws eks wait nodegroup-active \
        --cluster-name "$CLUSTER_NAME" \
        --nodegroup-name "$NODE_GROUP" \
        --region "$REGION"

    echo ""
    echo "Scaling complete!"
    echo ""
    echo "Current status:"
    aws eks describe-nodegroup \
        --cluster-name "$CLUSTER_NAME" \
        --nodegroup-name "$NODE_GROUP" \
        --region "$REGION" \
        --query 'nodegroup | {Status: status, Current: scalingConfig.desiredSize}' \
        --output table
}

scale_aks_node_group() {
    echo "Scaling AKS node pool..."
    az aks nodepool scale \
        --resource-group "${CLUSTER_NAME}-rg" \
        --cluster-name "$CLUSTER_NAME" \
        --name "$NODE_GROUP" \
        --node-count "$SCALE_COUNT" \
        --output table

    echo ""
    echo "Scaling complete!"
    echo ""
    echo "Current status:"
    az aks nodepool show \
        --resource-group "${CLUSTER_NAME}-rg" \
        --cluster-name "$CLUSTER_NAME" \
        --name "$NODE_GROUP" \
        --query "{Name: name, Status: provisioningState, Count: count}" \
        --output table
}

scale_gke_node_group() {
    echo "Scaling GKE node pool..."
    gcloud container clusters resize "$CLUSTER_NAME" \
        --node-pool "$NODE_GROUP" \
        --num-nodes "$SCALE_COUNT" \
        --region "$REGION" \
        --quiet

    echo ""
    echo "Waiting for resize to complete..."
    gcloud container node-pools wait "$NODE_GROUP" \
        --cluster "$CLUSTER_NAME" \
        --region "$REGION"

    echo ""
    echo "Scaling complete!"
    echo ""
    echo "Current status:"
    gcloud container node-pools describe "$NODE_GROUP" \
        --cluster "$CLUSTER_NAME" \
        --region "$REGION" \
        --format="table(name.status,status.nodeCount)"
}

# Parse arguments and execute
parse_args "$@"
