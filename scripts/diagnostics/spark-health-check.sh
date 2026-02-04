#!/bin/bash
# Spark K8s Health Check Script
# Part of WS-019-03: Centralized Troubleshooting

set -e

echo "🔍 Spark K8s Health Check"
echo "=========================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ kubectl found${NC}"
}

check_cluster() {
    if ! kubectl get nodes &> /dev/null; then
        echo -e "${RED}❌ Cannot access cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Cluster accessible${NC}"
}

check_pods() {
    echo ""
    echo "📊 Checking Spark pods..."

    PENDING=$(kubectl get pods -l app.kubernetes.io/part-of=spark-k8s --field-selector=status.phase=Pending 2>/dev/null | grep -c "Pending" || true)
    FAILED=$(kubectl get pods -l app.kubernetes.io/part-of=spark-k8s --field-selector=status.phase=Failed 2>/dev/null | grep -c "Failed" || true)
    OOMKILLED=$(kubectl get pods -l app.kubernetes.io/part-of=spark-k8s -o json | grep -c "OOMKilled" || true)

    if [ "$PENDING" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $PENDING pod(s) in Pending state${NC}"
        kubectl get pods -l app.kubernetes.io/part-of=spark-k8s --field-selector=status.phase=Pending
    fi

    if [ "$FAILED" -gt 0 ]; then
        echo -e "${RED}❌ $FAILED pod(s) failed${NC}"
        kubectl get pods -l app.kubernetes.io/part-of=spark-k8s --field-selector=status.phase=Failed
    fi

    if [ "$OOMKILLED" -gt 0 ]; then
        echo -e "${RED}❌ $OOMKILLED pod(s) OOMKilled${NC}"
        echo "See: docs/operations/troubleshooting.md#memory-issues"
    fi

    RUNNING=$(kubectl get pods -l app.kubernetes.io/part-of=spark-k8s --field-selector=status.phase=Running 2>/dev/null | grep -c "Running" || true)
    echo -e "${GREEN}✅ $RUNNING pod(s) running${NC}"
}

check_services() {
    echo ""
    echo "🔌 Checking Spark services..."

    SERVICES=("spark-connect" "spark-history" "jupyter" "grafana" "prometheus")

    for svc in "${SERVICES[@]}"; do
        if kubectl get svc "$svc" &> /dev/null; then
            TYPE=$(kubectl get svc "$svc" -o jsonpath='{.spec.type}')
            PORT=$(kubectl get svc "$svc" -o jsonpath='{.spec.ports[0].port}')
            echo -e "${GREEN}✅ $svc${NC} ($TYPE, port $PORT)"
        else
            echo -e "${YELLOW}⚠️  $svc not found${NC}"
        fi
    done
}

check_resources() {
    echo ""
    echo "💻 Checking node resources..."

    TOTAL_CPU=$(kubectl top nodes 2>/dev/null | tail -n +2 | awk '{sum+=$2} END {print sum}' || echo "N/A")
    TOTAL_MEM=$(kubectl top nodes 2>/dev/null | tail -n +2 | awk '{sum+=$4} END {print sum}' || echo "N/A")
    USED_CPU=$(kubectl top nodes 2>/dev/null | tail -n +2 | awk '{sum+=$3} END {print sum}' || echo "N/A")
    USED_MEM=$(kubectl top nodes 2>/dev/null | tail -n +2 | awk '{sum+=$5} END {print sum}' || echo "N/A")

    echo "CPU Usage: $USED_CPU / $TOTAL_CPU"
    echo "Memory Usage: $USED_MEM / $TOTAL_MEM"
}

check_storage() {
    echo ""
    echo "💾 Checking storage..."

    PENDING_PVC=$(kubectl get pvc --field-selector=status.phase=Pending 2>/dev/null | grep -c "Pending" || true)

    if [ "$PENDING_PVC" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $PENDING_PVC PVC(s) in Pending state${NC}"
        kubectl get pvc --field-selector=status.phase=Pending
    else
        echo -e "${GREEN}✅ All PVCs bound${NC}"
    fi
}

check_recent_errors() {
    echo ""
    echo "🐛 Checking recent errors..."

    echo "Recent errors in Spark pods:"
    kubectl logs -l app.kubernetes.io/part-of=spark-k8s --tail=20 2>/dev/null | grep -i "error\|exception\|failed" | tail -5 || echo "No recent errors found"
}

main() {
    check_kubectl
    check_cluster
    check_pods
    check_services
    check_resources
    check_storage
    check_recent_errors

    echo ""
    echo "=========================="
    echo "For troubleshooting help, see:"
    echo "  📖 docs/operations/troubleshooting.md"
    echo "  💬 Telegram: https://t.me/spark_k8s"
    echo ""
}

main
